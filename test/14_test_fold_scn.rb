#!/usr/bin/ruby1.9.1

$:.push 'test/lib'
require 'standalone_env'

class Env < StandAloneEnv
  def config
    super + <<EOD
object_space[0].enabled = 1
object_space[0].index[0].type = "HASH"
object_space[0].index[0].unique = 1
object_space[0].index[0].key_field[0].fieldno = 0
object_space[0].index[0].key_field[0].type = "STR"
EOD
  end
end

env = Env.clean

env.with_server do
  12.times {|i| insert [i,i]}

  puts `./octopus --fold 2 -vALL=-2 2>/dev/null`
end
