let expires_per_second = 1000;
let batch_size = 100;

include Box_space;
include Box_index;

let hash_loop = (pk, pred, ini) => {
  let slots = index_slots(pk);
  let batch = ref([]);
  let i = ref(ini);
  let j = ref(batch_size);
  while (i^ < slots && j^ > 0) {
    try(
      switch (pred(index_get(pk, i^))) {
      | Some(key) => batch := [key, ...batch^]
      | None => ()
      }
    ) {
    | Not_found => ()
    };
    incr(i);
    decr(j);
  };
  switch (batch^) {
  | [] => (None, [])
  | list => (Some(i^), list)
  };
};

let tree_loop = (pk, pred, ini) => {
  let rec loop = (i, batch) =>
    switch (pred(iterator_next(pk, 1))) {
    | Some(key) =>
      if (i == 1) {
        [key, ...batch];
      } else {
        loop(i - 1, [key, ...batch]);
      }
    | None => loop(i, batch)
    | exception Not_found => batch
    };
  iterator_init(pk, ini, Iter_forward);
  switch (loop(batch_size, [])) {
  | [hd, ...tl] => (Some(Iter_key(hd)), [hd, ...tl])
  | [] => (None, [])
  };
};

/* every space modification must be done _outside_ of iterator running */
let delete = (space, batch) => {
  let cb = key =>
    try(box_delete(space, key)) {
    | [@implicit_arity] Octopus.IProto_Failure(code, reason) =>
      Say.warn("delete failed: %s", reason)
    };
  List.iter(cb, batch);
};

let delay = batch =>
  Fiber.sleep(
    float((List.length(batch) + 1) * batch_size)
    /. float((batch_size + 1) * expires_per_second),
  );

type expire_state =
  | Running
  | Stop
  | Empty;
let state = ref(Empty);

let loop = (obj_space, pred) => {
  let pk = obj_space_pk(obj_space);
  let rec aux = (inner_loop, ini) =>
    if (state^ == Running) {
      switch (inner_loop(pk, pred, ini)) {
      | (Some(next), batch) =>
        delete(obj_space, batch);
        delay(batch);
        aux(inner_loop, next);
      | (None, _) => ()
      };
    };
  switch (index_type(pk)) {
  | HASH
  | NUMHASH => aux(hash_loop, 0)
  | _ => aux(tree_loop, Iter_empty)
  };
};

external stub_next_primary_box: unit => Box.box =
  "stub_box_next_primary_shard";

let expire = (no, key_info, pred, info) => {
  try(
    while (state^ != Empty) {
      if (state^ == Running) {
        state := Stop;
      };
      Fiber.sleep(1.0);
    }
  ) {
  | Not_found => ()
  };
  Fiber.create(
    ((no, key_info, pred)) => {
      state := Running;
      while (state^ == Running) {
        try({
          let box = stub_next_primary_box();
          let obj_space = Box_space.obj_space(box, no, key_info);
          loop(obj_space, pred);
        }) {
        | e => Say.warn("%s", Printexc.to_string(e))
        };
        Fiber.sleep(1.0);
      };
      state := Empty;
    },
    (no, key_info, pred),
  );
};
