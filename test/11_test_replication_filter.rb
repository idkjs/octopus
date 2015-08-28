#!/usr/bin/ruby

$: << File.dirname($0) + '/lib'
require 'run_env'

class MasterEnv < RunEnv
  def test_root
    super << "_master"
  end

  def config
    super + <<EOD
wal_feeder_bind_addr = "0:33034"
object_space[0].index[0].key_field[0].type = "NUM"
EOD
  end

  task :setup => ["feeder_init.lua"]
  file "feeder_init.lua" do
    f = open("feeder_init.lua", "w")
    f.write <<-EOD
local wal = require 'wal'
local box = require 'box.op'

function replication_filter.test_filter(row)
  print(row)

  if row:tag_name() ~= 'wal_tag' and not row:tag_name():find('usr') then
  	return true
  end

  if row.scn < 5 and row.scn % 2 == 0 then
   	return false
  end

  local cmd = box.wal_parse(row.tag, row.data, row.len)
  if not cmd then
      print("can't parse cmd")
      return true
  end

  if cmd.op == box.op.UPDATE_FIELDS then
      for _, v in ipairs(cmd.update_mops) do
          if v[2] == "add" then
              v[3] = v[3] + 1  -- preserve type
          end
      end

      local flags = 0
      local _, data, len = box.pack.update(flags, cmd.n, cmd.key:strfield(0), cmd.update_mops)
      return row:update_data(data, len)
  end
  return true
end
    EOD
    f.close
  end
end

class SlaveEnv < RunEnv
  def initialize
    @primary_port = 33023
    @test_root_suffix = "_slave"
    super
  end

  def config
    super + <<EOD
wal_feeder_addr = "127.0.0.1:33034"
wal_feeder_filter = "test_filter"
sync_scn_with_lsn = 0
panic_on_scn_gap = 0

object_space[0].index[0].key_field[0].type = "NUM"
EOD
  end
end

master_env = MasterEnv.new
master = master_env.env_eval do
  start
  connect
end

SlaveEnv.new.env_eval do
  start
  slave = connect

  6.times do |i|
    master.insert [i, i]
  end
  master.update_fields 4, [1, :add, 1]
  master.update_fields 5, [1, :add, 1]

  wait_for "non empty xlog" do
    File.size("00000000000000000002.xlog") > 400
  end

  master.select 0,1,2,3,4,5
  slave.select 0,1,2,3,5

  restart
  master_env.stop

  puts "Slave\n" + `./octopus --cat 00000000000000000002.xlog 2>/dev/null| sed 's/tm:[^ ]* //'` + "\n"
  master_env.cd do
    puts "Master\n" + `./octopus --cat 00000000000000000002.xlog 2>/dev/null| sed 's/tm:[^ ]* //'` + "\n"
  end
end

