open Printf;

type box;
type txn;

external submit: unit => int = "stub_box_submit";
[@noalloc] external txn: unit => txn = "stub_txn";

module Hashtbl =
  Hashtbl.Make({
    type t = string;
    let equal = (a: string, b: string) => a == b;
    let hash = Hashtbl.hash;
  });

let registry = Hashtbl.create(10);

let assert_count = (proc_name, args, n) =>
  if (Array.length(args) !== n) {
    Say.error(
      "invalid argument count for %s: want %i, got %i",
      proc_name,
      n,
      Array.length(args),
    );
    raise(
      [@implicit_arity]
      Octopus.IProto_Failure(0x2702, "Invalid argument count"),
    );
  };

let register_cb0 = (name, cb) =>
  Hashtbl.replace(
    registry,
    name,
    args => {
      assert_count(name, args, 0);
      cb();
    },
  );
let register_cb1 = (name, cb) =>
  Hashtbl.replace(
    registry,
    name,
    args => {
      assert_count(name, args, 1);
      cb(args[0]);
    },
  );
let register_cb2 = (name, cb) =>
  Hashtbl.replace(
    registry,
    name,
    args => {
      assert_count(name, args, 2);
      cb(args[0], args[1]);
    },
  );
let register_cb3 = (name, cb) =>
  Hashtbl.replace(
    registry,
    name,
    args => {
      assert_count(name, args, 3);
      cb(args[0], args[1], args[2]);
    },
  );
let register_cb4 = (name, cb) =>
  Hashtbl.replace(
    registry,
    name,
    args => {
      assert_count(name, args, 4);
      cb(args[0], args[1], args[2], args[3]);
    },
  );
let register_cb5 = (name, cb) =>
  Hashtbl.replace(
    registry,
    name,
    args => {
      assert_count(name, args, 5);
      cb(args[0], args[1], args[2], args[3], args[4]);
    },
  );
let register_cbN = (name, cb) => Hashtbl.replace(registry, name, cb);

let dispatch = ((wbuf, request), name: string, args: array(string)) => {
  let cb = Hashtbl.find(registry, name);
  try({
    let out = cb(args);
    if (submit() === (-1)) {
      raise(
        [@implicit_arity] Octopus.IProto_Failure(0x2702, "wal write failed"),
      );
    };
    let iproto = Net_io.reply(wbuf, request);
    Net_io.add_i32(wbuf, List.length(out));
    List.iter(tup => Box_tuple.net_add(wbuf, tup), out);
    Net_io.fixup(wbuf, iproto);
  }) {
  | [@implicit_arity] Octopus.IProto_Failure(code, msg) =>
    Net_io.error(wbuf, request, code, msg)
  | e =>
    open Printexc;
    Say.error(
      "Exception in %s : %s\nBacktrace: %s",
      name,
      to_string(e),
      get_backtrace(),
    );
    Net_io.error(
      wbuf,
      request,
      0x2702,
      sprintf("Exception: %s", to_string(e)),
    );
  };
};

[@noalloc]
external stub_get_affected_obj: unit => Octopus.oct_obj =
  "stub_get_affected_obj";
let get_affected_tuple = () =>
  try(Some(Box_tuple.of_oct_obj(stub_get_affected_obj()))) {
  | Not_found => None
  };

let _ = Callback.register("box_dispatch", dispatch);
