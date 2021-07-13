open Batteries;

let loaded = Hashtbl.create(10);

type plugin = {
  name: string,
  version: int,
  path: string,
};

let load = ({name, path, version}) =>
  try(
    if (!Hashtbl.mem(loaded, path)) {
      Say.info("Loading caml plugin %s, version %i", name, version);
      Hashtbl.add(loaded, path, true);
      Dynlink.loadfile(path);
    }
  ) {
  | Dynlink.Error(e) => Say.error("%s", Dynlink.error_message(e))
  };

let re = Str.regexp("\\(.*\\)[_.-]\\([0-9]+\\)\\.cmxs$");
let cmxs = Str.regexp("\\.cmxs$");
let is_plugin = (dir_name, file_name) => {
  let str_match = (re, str) =>
    try(
      {
        ignore(Str.search_forward(re, file_name, 0));
        true;
      }
    ) {
    | Not_found => false
    };
  if (str_match(re, file_name)) {
    Some({
      name: Str.matched_group(1, file_name),
      version: int_of_string(Str.matched_group(2, file_name)),
      path: dir_name ++ "/" ++ file_name,
    });
  } else {
    if (str_match(cmxs, file_name)) {
      Say.warn(
        "Can't parse `%s'. Plugin must be named as plugin_123.cmxs",
        file_name,
      );
      assert(false);
    };
    None;
  };
};

let readdir = dir_name =>
  Sys.readdir(dir_name) |> Array.filter_map(is_plugin(dir_name));

let new_plugins = pathlist => {
  let max = (hash, a) =>
    try(
      if (Hashtbl.find(hash, a.name).version < a.version) {
        Hashtbl.replace(hash, a.name, a);
      }
    ) {
    | Not_found => Hashtbl.add(hash, a.name, a)
    };
  let hash = Hashtbl.create(5);
  List.iter(Array.iter(max(hash)) % readdir, pathlist);
  Hashtbl.values(hash);
};

let plugin_loader = path => {
  let loader = pathlist =>
    while (true) {
      try(Enum.iter(load, new_plugins(pathlist))) {
      | exc => Say.warn("caml exception: %s", Printexc.to_string(exc))
      };
      Fiber.sleep(1.0);
    };
  Fiber.create(loader, Str.split(Str.regexp(":"), path));
};

let _ = Callback.register("plugin_loader", plugin_loader);
