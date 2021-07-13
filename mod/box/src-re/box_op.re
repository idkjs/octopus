open Packer;

type mop =
  | Set16((int, int))
  | Set32((int, int))
  | Set64((int, Int64.t))
  | Add16((int, int))
  | Add32((int, int))
  | Add64((int, Int64.t))
  | And16((int, int))
  | And32((int, int))
  | And64((int, Int64.t))
  | Or16((int, int))
  | Or32((int, int))
  | Or64((int, Int64.t))
  | Xor16((int, int))
  | Xor32((int, int))
  | Xor64((int, Int64.t))
  | Set((int, bytes))
  | Splice(int)
  | Delete(int)
  | Insert((int, bytes));

let msg_nop = 1;
let msg_insert = 13;
let msg_update_fields = 19;
let msg_delete = 21;

external dispatch: (Box.txn, int, Packer.t) => unit = "stub_box_dispatch";

let pack_tuple = (pa, tuple) => {
  open Box_tuple;
  let (cardinal, _) = tuple_cardinal_and_bsize(tuple);
  Packer.add_i32(pa, cardinal);
  switch (tuple) {
  | Heap(o) =>
    for (i in 0 to cardinal - 1) {
      Packer.add_bytes(pa, heap_tuple_field(o, FRaw, i));
    }
  | Gc(o) =>
    let rec pack = (pa, f) =>
      Packer.(
        switch (f) {
        | I8(v) =>
          add_i8(pa, 1);
          add_i8(pa, v);
        | I16(v) =>
          add_i8(pa, 2);
          add_i16(pa, v);
        | I32(v) =>
          add_i8(pa, 4);
          add_i32(pa, v);
        | I64(v) =>
          add_i8(pa, 8);
          add_i64(pa, v);
        | Bytes(v) => add_field_bytes(pa, v)
        | [@implicit_arity] Field(Heap(o), n) =>
          add_bytes(pa, heap_tuple_field(o, FRaw, n))
        | [@implicit_arity] Field(Gc(o), n) => pack(pa, List.nth(o, n))
        | FieldRange(_) => failwith("not implemented")
        }
      );
    List.iter(pack(pa), o);
  };
};

let insert = (txn, ~flags=0, n, tuple) => {
  let pa = create(128);
  add_i32(pa, n);
  add_i32(pa, flags);
  pack_tuple(pa, tuple);
  dispatch(txn, msg_insert, pa);
};

let upsert = (txn, n, tuple) => insert(txn, ~flags=1, n, tuple);

let add = (txn, n, tuple) => insert(txn, ~flags=3, n, tuple);

let replace = (txn, n, tuple) => insert(txn, ~flags=5, n, tuple);

let delete = (txn, n, key) => {
  let pa = create(32);
  add_i32(pa, n);
  add_i32(pa, 1); /* flags */
  pack_tuple(pa, key);
  dispatch(txn, msg_delete, pa);
};

let pack_mop = (pa, mop) =>
  switch (mop) {
  | [@implicit_arity] Set(idx, v) =>
    add_i32(pa, idx);
    add_i8(pa, 0);
    add_field_bytes(pa, v);

  | [@implicit_arity] Set16(idx, v) =>
    add_i32(pa, idx);
    add_i8(pa, 0);
    add_i8(pa, 2);
    add_i16(pa, v);
  | [@implicit_arity] Set32(idx, v) =>
    add_i32(pa, idx);
    add_i8(pa, 0);
    add_i8(pa, 4);
    add_i32(pa, v);
  | [@implicit_arity] Set64(idx, v) =>
    add_i32(pa, idx);
    add_i8(pa, 0);
    add_i8(pa, 8);
    add_i64(pa, v);

  | [@implicit_arity] Add16(idx, v) =>
    add_i32(pa, idx);
    add_i8(pa, 1);
    add_i8(pa, 2);
    add_i16(pa, v);
  | [@implicit_arity] Add32(idx, v) =>
    add_i32(pa, idx);
    add_i8(pa, 1);
    add_i8(pa, 4);
    add_i32(pa, v);
  | [@implicit_arity] Add64(idx, v) =>
    add_i32(pa, idx);
    add_i8(pa, 1);
    add_i8(pa, 8);
    add_i64(pa, v);

  | [@implicit_arity] And16(idx, v) =>
    add_i32(pa, idx);
    add_i8(pa, 2);
    add_i8(pa, 2);
    add_i16(pa, v);
  | [@implicit_arity] And32(idx, v) =>
    add_i32(pa, idx);
    add_i8(pa, 2);
    add_i8(pa, 4);
    add_i32(pa, v);
  | [@implicit_arity] And64(idx, v) =>
    add_i32(pa, idx);
    add_i8(pa, 2);
    add_i8(pa, 8);
    add_i64(pa, v);

  | [@implicit_arity] Or16(idx, v) =>
    add_i32(pa, idx);
    add_i8(pa, 3);
    add_i8(pa, 2);
    add_i16(pa, v);
  | [@implicit_arity] Or32(idx, v) =>
    add_i32(pa, idx);
    add_i8(pa, 3);
    add_i8(pa, 4);
    add_i32(pa, v);
  | [@implicit_arity] Or64(idx, v) =>
    add_i32(pa, idx);
    add_i8(pa, 3);
    add_i8(pa, 8);
    add_i64(pa, v);

  | [@implicit_arity] Xor16(idx, v) =>
    add_i32(pa, idx);
    add_i8(pa, 4);
    add_i8(pa, 2);
    add_i16(pa, v);
  | [@implicit_arity] Xor32(idx, v) =>
    add_i32(pa, idx);
    add_i8(pa, 4);
    add_i8(pa, 4);
    add_i32(pa, v);
  | [@implicit_arity] Xor64(idx, v) =>
    add_i32(pa, idx);
    add_i8(pa, 4);
    add_i8(pa, 8);
    add_i64(pa, v);

  | Splice(idx) =>
    add_i32(pa, idx);
    add_i8(pa, 5);
    failwith("not implemented");

  | Delete(idx) =>
    add_i32(pa, idx);
    add_i8(pa, 6);
    add_i8(pa, 0);
  | [@implicit_arity] Insert(idx, v) =>
    add_i32(pa, idx);
    add_i8(pa, 7);
    add_field_bytes(pa, v);
  };

let update = (txn, n, key, mops) => {
  let count = List.length(mops);
  let pa = create(32 + count * 8);
  add_i32(pa, n);
  add_i32(pa, 1); /* flags = return tuple */
  pack_tuple(pa, key);
  add_i32(pa, count);
  List.iter(mop => pack_mop(pa, mop), mops);
  dispatch(txn, msg_update_fields, pa);
};
