type file = string
type input = Stdin | File of file
type output = Stdout | File of file

type command =
  | Version
  | Check of input list
  | Inplace of file list
  | Format of input * output

let usage =
  "opam fmt [--stdin | --inplace | --check] FILE(S)      \
   (see --help for more options)"

let command () =
  let files = ref [] in
  let version = ref false in
  let check = ref false in
  let inplace = ref false in
  let stdin = ref false in
  let output = ref None in
  Arg.parse
    (Arg.align [
      "--version", Arg.Set version,
        " Print the expected opam file version and exits";
      "--check", Arg.Set check,
        " Check that reformatting the input file(s) would be a no-op";
      "--inplace", Arg.Set inplace,
        "FILES Modify one or several input files in place";
      "--stdin", Arg.Set stdin,
        " Read from standard input";
      "--output", Arg.String (fun file -> output := Some file),
        "FILE Format a single input file, and write output to the given output file";
    ])
    (fun file -> files := file :: !files)
    usage;
  (* the files have been accumulated in the reverse order *)
  let files = List.rev !files in
  if !version then Some Version
  else begin match files, !check, !inplace, !stdin, !output with
    | _, true, true, _, _ ->
      prerr_endline "options --check and --inplace are incompatible";
      None
    | _, true, _, _, Some _ ->
      prerr_endline "options --check and --output are incompatible";
      None
    | _, _, true, _, Some _ ->
      prerr_endline "options --inplace and --output are incompatible";
      None
    | _, _, true, true, _ ->
      prerr_endline "options --inplace and --stdin are incompatible";
      None
    | (_ :: _ :: _), false, false, false, _
    | (_ :: _), false, false, true, _ ->
      prerr_endline "you can only use multiple sources with --check or --inplace";
      None
    | [], false, false, false, Some _ ->
      prerr_endline "no input source given";
      None
    | [], false, false, false, None ->
      None
    | files, true, false, stdin, None ->
      let inputs =
        (if stdin then [Stdin] else [])
        @ List.map (fun file -> (File file : input)) files in
      Some (Check inputs)
    | files, false, true, false, None ->
      Some (Inplace files)
    | [], false, false, true, None ->
      Some (Format (Stdin, Stdout))
    | [], false, false, true, Some out_file ->
      Some (Format (Stdin, File out_file))
    | [in_file], false, false, false, None ->
      Some (Format (File in_file, Stdout))
    | [in_file], false, false, false, Some out_file ->
      Some (Format (File in_file, File out_file))
  end

module OF = OpamFilename

let with_tmp_file action =
  let module OF = OpamFilename in
  OF.with_tmp_dir (fun tmp ->
      action (OF.OP.(//) tmp "file"))

type return = Success | Check_failure | Version_failure

module OPAM = OpamFile.OPAM

type content = string

type result =
  | Same
  | New of content
  | Future_opam_version of OpamVersion.t

let reformat_file src_file =
  let src = OF.of_string src_file in
  let opam = OPAM.read src in
  let file_version = OPAM.opam_version opam in
  let curr_version = OpamVersion.current_nopatch in
  (* note: we use [current_nopatch] as the current version, but only
     give up on future version if they are strictly after [current]. *)
  if OpamVersion.compare OpamVersion.current file_version < 0
  then Future_opam_version file_version
  else with_tmp_file (fun dst ->
      let opam = OPAM.with_opam_version opam curr_version in
      OPAM.write dst opam;
      let src_content = OF.read src in
      let dst_content = OF.read dst in
      if src_content = dst_content then Same
      else New dst_content
    )

let reformat_input : input -> result = function
  | File file -> reformat_file file
  | Stdin ->
      let input = OpamSystem.string_of_channel stdin in
      with_tmp_file (fun file ->
          let file = OpamFilename.to_string file in
          OpamSystem.write file input;
          reformat_file file)

let write_output output content =
  match output with
  | Stdout ->
    print_string content
  | File file ->
    OpamSystem.write file content

let msg_check_failure file =
  Printf.printf "%S is not correctly formatted.\n%!" file

let msg_version_failure file file_version =
  let curr_version = OpamVersion.current_nopatch in
  Printf.printf
    "The currently supported version is %S. \
     File %S requires future version %S, so it was skipped.\n%!"
    (OpamVersion.to_string curr_version)
    file
    (OpamVersion.to_string file_version)

let msg_replacement file =
  Printf.printf "%S has been rewritten in place.\n%!" file

let name_of_input = function
| Stdin -> "<stdin>"
| File file -> file

let run = function
  | Version ->
    print_endline (OpamVersion.to_string OpamVersion.current_nopatch);
    Success

  | Format (input, output) ->
    begin match reformat_input input with
      | Same ->
        Success
      | New content ->
        write_output output content;
        Success
      | Future_opam_version version ->
        msg_version_failure (name_of_input input) version;
        Version_failure
    end

  | Check files ->
    let check_failure = ref false in
    let version_failure = ref false in
    let check input = match reformat_input input with
      | Same -> ()
      | New _content ->
        msg_check_failure (name_of_input input);
        check_failure := true;
      | Future_opam_version version ->
        msg_version_failure (name_of_input input) version;
        version_failure := true;
    in
    List.iter check files;
    (* Check_failure takes priority over Version_failure: if both have
       failed, Check failure is reported *)
    if !check_failure then Check_failure
    else if !version_failure then Version_failure
    else Success

  | Inplace files ->
    let version_failure = ref false in
    let replace file = match reformat_file file with
      | Same -> ()
      | New content ->
        OpamSystem.write file content;
        msg_replacement file
      | Future_opam_version version ->
        msg_version_failure file version;
        version_failure := true
    in
    List.iter replace files;
    if !version_failure then Version_failure
    else Success

let () =
  match command () with
  | None -> print_endline usage
  | Some command ->
    begin match run command with
      | Success -> exit 0
      | Version_failure -> exit 1
      | Check_failure -> exit 2
    end
