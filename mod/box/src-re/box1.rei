module Say: {
  let error: format4('a, unit, string, unit) => 'a;
  let warn: format4('a, unit, string, unit) => 'a;
  let info: format4('a, unit, string, unit) => 'a;
  let debug: format4('a, unit, string, unit) => 'a;

  /** Printf.printf аналоги для печати в журнал октопуса */;
};

module Fiber: {
  /** [create cb arg] запускает фибер и выполняет внутри него
      [cb arg] */
  external create: ('a => unit, 'a) => unit = "stub_fiber_create";

  /** [sleep delay] приостанаваливает выполнение на [delay]
      секунд. Другие фиберы продолжат испольняться */
  external sleep: float => unit = "stub_fiber_sleep";

  /** [loop name cb] создает фибер и вызывает в бесконечном цикле
      [cb ()], при повторном вызове с тем же [name] заменяет [cb] в
      существующем фибере. Замена произходит после того, как [cb]
      вернет управление. Поэтому не стоит застревать в нем очень
      надолго. */

  let loop: (string, unit => unit) => unit;
};

module Packer: {
  /** Автоматически расширяемый буфер, предназначенный для упаковки
      бинарных данных. */

  type t;

  /** [create n] создает пустой packer. Параметр [n] указывает,
      сколько будет предвыделнно байт в буфере. Для оптимальной
      производительности он должен быть примерно равен результирующему
      размеру */

  let create: int => t;

  /** Возвращает копию содержимого packer */

  let contents: t => bytes;

  /** [clear pa] очищает packer. Внутренний буфер при этом не
      освобождается */

  let clear: t => unit;

  /** [need pa size] резервирует [size] байт во внутреннем
      буфере и возвращает смещение на их начало. Данное смещение потом
      можно использовать как аргумент [pos] в семействе функций
      Packer.blit_{i8,i16,i32,i64,ber} */

  let need: (t, int) => int;

  /** [blit_i8 pa pos n] сохраняет [n] как 1-байтное число по
      смещению [pos]. */

  let blit_i8: (t, int, int) => unit;

  /** [blit_i16 pa pos n] сохраняет [n] как 2-байтное число по
      смещению [pos] */

  let blit_i16: (t, int, int) => unit;

  /** [blit_i32 pa pos n] сохраняет [n] как 4-байтоное число по
      смещению [pos] */

  let blit_i32: (t, int, int) => unit;

  /** [blit_i64 pa pos n] сохраняет [n] как 8-байтное число по
      смещению [pos] */

  let blit_i64: (t, int, Int64.t) => unit;

  /** [blit_varint32 pa pos n] сохраняет [n] как число в формате BER
      (perl pack 'w') по смещению [pos] */

  let blit_varint32: (t, int, int) => int;

  /** [blit_bytes pa pos src srcoff len] копирует [len] байтов из [src] по смещению
      [srcoff] в буфер по смещению [pos] */

  let blit_bytes: (t, int, bytes, int, int) => unit;

  /** [add_i8 pa n] дописывает [n] в конец буфера как 1-байтное
      число */

  let add_i8: (t, int) => unit;

  /** [add_i16 pa n] дописывает [n] в конец буфера как
      2-байтное число */

  let add_i16: (t, int) => unit;

  /** [add_i32 pa n] дописывает [n] в конец буфера как
      4-байтное число */

  let add_i32: (t, int) => unit;

  /** [add_i64 pa n] дописывает [n] в конец буфера как
      8-байтное число */

  let add_i64: (t, Int64.t) => unit;

  /** [add_varint32 pa n] дописывает [n] в конец буфера как число в
      формате BER (perl pack 'w') */

  let add_varint32: (t, int) => unit;

  /** [add_bytes pa bytes] дописывет содержимое [bytes] в конец
      буфера */

  let add_bytes: (t, bytes) => unit;

  /** [add_packer pa pa2] дописывет содержимое другого packer в
      конец буфера */

  let add_packer: (t, t) => unit;

  /** [add_field_bytes pa bytes] дописывает [bytes], в виде поля
      кортежа octopus/silverbox, то есть сперва длина [bytes]
      в закодированная в BER, а потом содержимое [bytes] */

  let add_field_bytes: (t, bytes) => unit;

  /** [int_of_bits bytes pos] преобразует 1 байт по смещению
      [pos] в число, так как это бы сделал сделующий C код:
      *(int8_t * )([bytes] + [pos]) */

  let int8_of_bits: (bytes, int) => int;

  /** [int_of_bits bytes pos] преобразует 2 байта по смещению
      [pos] в число, так как это бы сделал сделующий C код:
      *(int16_t * )([bytes] + [pos]) */

  let int16_of_bits: (bytes, int) => int;

  /** [int_of_bits bytes pos] преобразует 4 байта по смещению
      [pos] в число, так как это бы сделал сделующий C код:
      *(int32_t * )([bytes] + [pos]) */

  let int32_of_bits: (bytes, int) => int;

  /** [int64_of_bits bytes pos] преобразует 8 байт по смещению
      [pos] в число, так как это бы сделал сделующий C код:
      *(int64_t * )([bytes] + [pos]) */

  let int64_of_bits: (bytes, int) => Int64.t;

  /** [bits_of_int16 n] возвращает 2-байтовое представление [n]. Если
      число не влезает в 2 байта, он будет обрезано */

  let bits_of_int16: int => bytes;

  /** [bits_of_int32 n] возвращает 4-байтовое представление [n]. Если
      число не влезает в 4-байта, он будет обрезано */

  let bits_of_int32: int => bytes;

  /** [bits_of_int64 n] возвращает 8-байтовое представление [n]. */

  let bits_of_int64: Int64.t => bytes;
};

/** абстрактный тип микрошарда. Может использоваться только внутри
    коллбека, попытка сохранить его где-нибудь и использовать вне коллбека
    приведет к SEGV */

type box;

/** абстракнтый тип кортежа, который хранится в box. Для доступа к
    полям надо использовать соответствующие аккцесоры из module
    Tuple */

type tuple;

/** [IProto_Failure of code * reason] в это исключение преобразуются
    ObjC исключение IProtoError */

exception IProto_Failure(int, string);

module Tuple: {
  type field =
    | I8(int)
    | I16(int)
    | I32(int)
    | I64(Int64.t)
    | Bytes(bytes)
    | Field(tuple, int)
    | FieldRange(tuple, int, int);

  /** [of_list field_list] преобразует список значений типа
      [field] в кортеж */

  let of_list: list(field) => tuple;

  /** [cardinal возвращает количество полей в кортеже. */

  let cardinal: tuple => int;

  /** [i8field tuple idx] возвращает числовое значение
      1-байтного поля, если длина поля не равна 1, то кидает
      исключение */

  let i8field: (int, tuple) => int;

  /** [i16field tuple idx] возвращает числовое значение
      2-байтного поля, если длина поля не равна 2, то кидает
      исключение */

  let i16field: (int, tuple) => int;

  /** [i32field tuple idx] возвращает числовое значение
      4-байтного поля, если длина поля не равна 4, то кидает
      исключение */

  let i32field: (int, tuple) => Int32.t;

  /** [i64field tuple idx] возвращает числовое значение
      8-байтного поля, если длина поля не равна 8, то кидает
      исключение */

  let i64field: (int, tuple) => Int64.t;

  /** [numfield tuple idx] возвращает числовое значение 1,2,4
      или 8-байтного поля, если длина поля не равна 1,2,4 или 8, то
      кидает исключение. 64 битное значение обрезается до размерности
      int */

  let numfield: (int, tuple) => int;

  /** [strfield tuple idx] возвращает байтовое представление поля */

  let strfield: (int, tuple) => bytes;

  /** [strfield tuple idx] возвращает байтовое представление
      поля включая (!) BER-закодированную длину */

  let rawfield: (int, tuple) => bytes;
};

module Index: {
  type index;
  type index_type =
    | HASH
    | TREE;

  type iter_dir =
    | Iter_forward
    | /** направление итератора. Iter_backward поддерживается только для
      деревьев. */
      Iter_backward;

  external node_pack_int: (index, int) => unit = "stub_index_node_pack_int";
  external node_pack_u64: (index, Int64.t) => unit =
    "stub_index_node_pack_u64";
  external node_pack_string: (index, string) => unit =
    "stub_index_node_pack_string";

  module type Descr = {
    type key;
    let obj_space_no: int;
    let index_no: int;
    let node_pack: (index, key) => unit;
  };

  module Make:
    (Descr: Descr) =>
     {
      type iter_init =
        | Iter_empty
        | Iter_key(Descr.key)
        | Iter_partkey((int, Descr.key))
        | Iter_tuple(tuple)
        | /** алгебраический тип для инициализации итератора:
        Iter_empty для итерации с самого начала индекса,
        Iter_key 'key для произвольного ключа,
        Iter_partkey (int * 'key) для частичного ключа и
        Iter_tuple tuple для старта с [tuple] */
          Iter_position(
            int,
          );

      /** [iterator_init init dir] инициализирует итератор используя
        [init] в качестве начального значения и [dir] как
        направление. Если индекс это хеш, то [dir] должен быть
        Iter_forward */

      let iterator_init: (iter_init, iter_dir) => unit;

      /** [iterator_next ()] возвращает текущий кортеж; перемещает
        итератор на следующий */

      let iterator_next: unit => tuple;

      /** [iterator_skip ()] пропускает текущий кортеж; перемещает
        итератор на следующий */

      let iterator_skip: unit => unit;

      /** [iterator_take init dir count] возвращает список из [count]
        кортежей начания с [init] */

      let iterator_take: (iter_init, iter_dir, int) => list(tuple);

      /** [find key] находит кортеж в [index] по ключу
        [key]. Кидает исключение Not_found если не находит */

      let find: Descr.key => tuple;

      /** [find_by_tuple key_part_list] находит кортеж в [index] по
        полному или частичному ключу [key_part_list]. Функция чуть
        менее эффективна чем [find] т.к. требуется промежуточная
        структура, описывающая ключ. В случае, если тип ключа не
        совпадет с типом индекса, кинет исключение Invalid_argument.
        Кидает исключение Not_found если не находит */

      let find_dyn: list(Tuple.field) => tuple;

      let get: int => tuple;
      let slots: unit => int;
      let typ: unit => index_type;
    };
};

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
  | /** алгебраический тип, описывающий микрооперации в [box_update] */
    Insert(
      (int, bytes),
    );

module ObjSpace: {
  module type Descr = {
    type key;
    let obj_space_no: int;
    let index_no: int;
    let node_pack: (Index.index, key) => unit;
    let tuple_of_key: key => tuple;
  };

  module Make:
    (Descr: Descr) =>
     {
      /** См. описание Index.Make */

      module PK: {
        type iter_init =
          | Iter_empty
          | Iter_key(Descr.key)
          | Iter_partkey((int, Descr.key))
          | Iter_tuple(tuple)
          | Iter_position(int);
        let iterator_init: (iter_init, Index.iter_dir) => unit;
        let iterator_next: unit => tuple;
        let iterator_skip: unit => unit;
        let iterator_take: (iter_init, Index.iter_dir, int) => list(tuple);
        let find: Descr.key => tuple;
        let get: int => tuple;
        let slots: unit => int;
        let typ: unit => Index.index_type;
      };

      /** [find key] находит кортеж в PK по ключу [key]. Кидает
        исключение Not_found если не находит */

      let find: Descr.key => tuple;

      /** [upsert tuple] вставляет [tuple]. Если кортеж с таким же
        первичным ключом уже существует, то он заменяется.  */

      let upsert: tuple => unit;

      /** [replace tuple] заменяет [tuple]. Если кортежа с совпадающем
        ключом не существует, то кидает IProto_Failure */

      let replace: tuple => unit;

      /** [add obj_space tuple] добавляет [tuple]. Если кортеж с
        совпадающим ключом существует, то кидает IProto_Failure */

      let add: tuple => unit;

      /** [delete key] удаляет кортеж, соответсвующий [key] */

      let delete: Descr.key => unit;

      /** [update key mops] последовательно выполняет [mops] над кортжем
        с первичным ключом [key] в [obj_space] */

      let update: (Descr.key, list(mop)) => unit;
    };
};

/** возвращает affected кортеж после [replace], [update],
    [delete]. Должна вызываться непосредственно после соотвествующей
    операции */

let get_affected_tuple: unit => option(tuple);

/** [register_cb0 name cb] регистрирует коллбек без аргументов [cb] под именем [name].
    Если фактическое количество аргументов не совпадает, то вернет клиенту ошибку. */

let register_cb0: (string, unit => list(tuple)) => unit;

/** [register_cb1 name cb] регистрирует 1-аргументный коллбек [cb] под именем [name].
    Если фактическое количество аргументов не совпадает, то вернет клиенту ошибку.  */

let register_cb1: (string, string => list(tuple)) => unit;

/** см. [register_cb1] */

let register_cb2: (string, (string, string) => list(tuple)) => unit;

/** см. [register_cb1] */

let register_cb3: (string, (string, string, string) => list(tuple)) => unit;

/** см. [register_cb1] */

let register_cb4:
  (string, (string, string, string, string) => list(tuple)) => unit;

/** см. [register_cb1] */

let register_cb5:
  (string, (string, string, string, string, string) => list(tuple)) => unit;

/** тоже что и [register_cb1], но все аргументы коллбека будет переданы в виде массива. */

let register_cbN: (string, array(string) => list(tuple)) => unit;
