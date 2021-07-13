/* common modules */
module Say = Say;
module Fiber = Fiber;
module Packer = Packer;

/* Box API */
exception IProto_Failure = Octopus.IProto_Failure;

include Box;
module ObjSpace = Box_space;
module Tuple = Box_tuple;
module Index = Box_index;
type tuple = Tuple.t;
type mop =
  Box_op.mop =
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
