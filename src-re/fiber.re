external sleep: float => unit = "stub_fiber_sleep";
external create: ('a => unit, 'a) => unit = "stub_fiber_create";

let loops: Hashtbl.t(string, unit => unit) = (
  Hashtbl.create(2): Hashtbl.t(string, unit => unit)
);

let loop = (name, cb) =>
  if (Hashtbl.mem(loops, name)) {
    Hashtbl.replace(loops, name, cb);
  } else {
    create(
      () => {
        Hashtbl.add(loops, name, cb);
        try(
          while (true) {
            (Hashtbl.find(loops, name))();
          }
        ) {
        | e => Say.error("loop exception %s", Printexc.to_string(e))
        };
        Hashtbl.remove(loops, name);
      },
      (),
    );
  };
