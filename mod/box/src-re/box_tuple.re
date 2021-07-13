type heap_tuple;
type field =
  | I8(int)
  | I16(int)
  | I32(int)
  | I64(Int64.t)
  | Bytes(bytes)
  | Field(t, int)
  | FieldRange(t, int, int)
and t =
  | Heap(heap_tuple)
  | Gc(list(field));
type ftype(_) =
  | FI8: ftype(int)
  | FI16: ftype(int)
  | FI32: ftype(Int32.t)
  | FI64: ftype(Int64.t)
  | FInt: ftype(int)
  | FStr: ftype(bytes)
  | FRaw: ftype(bytes);

let heap =
  fun
  | Heap(o) => o
  | Gc(_) => failwith("accesing constructed tuple not implemented");

external heap_tuple_alloc: Octopus.oct_obj => heap_tuple =
  "box_tuple_custom_alloc";
[@noalloc]
external heap_tuple_raw_field_size: (heap_tuple, int) => int =
  "stub_box_tuple_raw_field_size";
[@noalloc]
external heap_tuple_bsize: heap_tuple => int = "stub_box_tuple_bsize";
[@noalloc]
external heap_tuple_cardinal: heap_tuple => int = "stub_box_tuple_cardinality";
external heap_tuple_field: (heap_tuple, ftype('a), int) => 'a =
  "stub_box_tuple_field";
[@noalloc]
external heap_tuple_net_add: (Net_io.wbuf, heap_tuple) => unit =
  "stub_net_tuple_add";

let of_oct_obj = o => Heap(heap_tuple_alloc(o)); /* will raise Not_found if obj == NULL */
let of_list = a => Gc(a);

let i8field = (n, tup) => heap_tuple_field(heap(tup), FI8, n);
let i16field = (n, tup) => heap_tuple_field(heap(tup), FI16, n);
let i32field = (n, tup) => heap_tuple_field(heap(tup), FI32, n);
let i64field = (n, tup) => heap_tuple_field(heap(tup), FI64, n);
let numfield = (n, tup) => heap_tuple_field(heap(tup), FInt, n);
let strfield = (n, tup) => heap_tuple_field(heap(tup), FStr, n);
let rawfield = (n, tup) => heap_tuple_field(heap(tup), FRaw, n);

let cardinal =
  fun
  | Heap(o) => heap_tuple_cardinal(o)
  | Gc(o) => List.length(o);

let rec tuple_raw_field_size = (tuple, n) =>
  switch (tuple) {
  | Heap(o) => heap_tuple_raw_field_size(o, n)
  | Gc(o) => gc_tuple_raw_field_size(List.nth(o, n))
  }
and gc_tuple_raw_field_size =
  fun
  | I8(_) => 1 + 1
  | I16(_) => 1 + 2
  | I32(_) => 1 + 4
  | I64(_) => 1 + 8
  | Bytes(b) => {
      let len = Bytes.length(b);
      Packer.Bytes.varint32_size(len) + len;
    }
  | [@implicit_arity] Field(t, n) => tuple_raw_field_size(t, n)
  | [@implicit_arity] FieldRange(t, n, count) => {
      let sum = ref(0);
      for (i in 0 to count - 1) {
        sum := sum^ + tuple_raw_field_size(t, n + 1);
      };
      sum^;
    };

let rec tuple_cardinal_and_bsize =
  fun
  | Heap(o) => (heap_tuple_cardinal(o), heap_tuple_bsize(o))
  | Gc(o) => {
      let cardinal = ref(0);
      let bsize = ref(0);
      List.iter(
        f => {
          incr(cardinal);
          bsize := bsize^ + gc_tuple_raw_field_size(f);
        },
        o,
      );
      (cardinal^, bsize^);
    };

[@noalloc]
external unsafe_blit_tuple_field: (bytes, int, heap_tuple, int, int) => int =
  "stub_box_tuple_blit_field";

let bytes_of_gc_tuple = a => {
  let (cardinal, bsize) = tuple_cardinal_and_bsize(Gc(a));
  let buf = Bytes.create(8 + bsize);
  let pos = ref(8);
  open Packer.Bytes;
  let rec blit_field = buf =>
    fun
    | I8(v) => pos := unsafe_blit_field_i8(buf, pos^, v)
    | I16(v) => pos := unsafe_blit_field_i16(buf, pos^, v)
    | I32(v) => pos := unsafe_blit_field_i32(buf, pos^, v)
    | I64(v) => pos := unsafe_blit_field_i64(buf, pos^, v)
    | Bytes(v) => pos := unsafe_blit_field_bytes(buf, pos^, v)
    | [@implicit_arity] Field(Heap(o), n) =>
      pos := unsafe_blit_tuple_field(buf, pos^, o, n, 1)
    | [@implicit_arity] Field(Gc(o), n) => blit_field(buf, List.nth(o, n))
    | [@implicit_arity] FieldRange(Heap(o), n, count) =>
      pos := unsafe_blit_tuple_field(buf, pos^, o, n, count)
    | [@implicit_arity] FieldRange(Gc(o), n, count) =>
      List.iter(blit_field(buf), BatList.take(count, BatList.drop(n, o)));

  unsafe_blit_i32(buf, 0, bsize);
  unsafe_blit_i32(buf, 4, cardinal);
  List.iter(blit_field(buf), a);
  assert(pos^ == 8 + bsize);
  buf;
};

let net_add = wbuf =>
  fun
  | Heap(o) => heap_tuple_net_add(wbuf, o)
  | Gc(a) => Net_io.add(wbuf, bytes_of_gc_tuple(a));
