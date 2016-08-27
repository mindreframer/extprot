
open Printf
open ExtList
open ExtString

module G = Gencode.Make(Gen_OCaml)
module PP = Gencode.Prettyprint

let (|>) x f = f x
let (@@) f x = f x

let file = ref None
let output = ref None
let generators = ref None
let width = ref 100

let arg_spec =
  Arg.align
    [
      "-o", Arg.String (fun f -> output := Some f), "FILE Set output file.";
      "-g", Arg.String (fun gs -> generators := Some (String.nsplit gs ",")),
        "LIST Generators to use (comma-separated).";
      "-w", Arg.Set_int width,
        sprintf "N Set width to N characters in generated code (default: %d)." !width;
    ]

let usage_msg =
  sprintf
    "\nUsage: extprotc [OPTIONS] <file>\n\n\
     Known generators:\n\n\
     %s\n\n\
     Options:\n" @@
    String.concat "\n" @@
      List.map
        (fun (lang, gens) -> sprintf "  %s: %s" lang @@ String.join ", " gens)
        [
          "OCaml", G.generators;
        ]

let print_header ?(sub = '=') fmt =
  kprintf
    (fun s ->
       Format.fprintf Format.err_formatter "%s@.%s@." s
         (String.make (String.length s) sub))
    fmt

let print fmt = Format.fprintf Format.err_formatter fmt

let () =
  Arg.parse arg_spec (fun fname -> file := Some fname) usage_msg;
  Option.may
    (fun file ->
       let output = match !output with
           None -> Filename.chop_extension file ^ ".ml"
         | Some f -> f in

       if output = file then begin
         print "extprotc: refusing to overwrite %S@." file;
         exit 2
       end;

       let och = open_out output in
       let decls = Parser.print_synerr Parser.parse_file file in
         begin
           match Ptypes.check_declarations decls with
               [] -> G.generate_code ~width:!width ?generators:!generators decls |> output_string och
             | errors ->
                 print "Found %d errors:@." (List.length errors);
                 Ptypes.pp_errors Format.err_formatter errors;
                 print "@.@]";
                 exit 1
         end;
         ignore @@ Gencode.collect_bindings decls)
    !file
