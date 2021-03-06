let blanks  = Str.regexp "[ \t]+"
let comment = Str.regexp "^//.*"
let sym_lex = Str.regexp "^[0-9A-Za-z_].*"

let analyze_gr file =
  let tparser = open_in file in
  let symbols = ref [] in
  let lexicon = ref [] in
  let tokens  = ref [] in
  try
    let in_tl = ref false in
    while true do
      let line = input_line tparser in
      if line = "// END TOKEN LIST" then in_tl := false;
      if !in_tl && not (Str.string_match comment line 0) then begin
	let line = Str.global_replace (Str.regexp "[\";]") "" line in
	let parts = Str.split blanks line in
	if List.length parts >= 3 then begin
	  let number :: (foo :: (token :: aliases)) = parts in
	  let number = int_of_string number in
	  tokens := (number, token) :: !tokens;
	  lexicon := (token, token) :: !lexicon;
	  List.iter (fun x ->
	    if x <> "//" then begin
	      if Str.string_match sym_lex x 0 then
		lexicon := (token, x) :: !lexicon
	      else
		symbols := (token, x) :: !symbols
	    end
		    ) aliases;
	end
      end;
      if line = "// BEGIN TOKEN LIST" then in_tl := true;
    done;
    (!symbols, !lexicon, !tokens)
  with End_of_file -> (close_in tparser; (!symbols, !lexicon, !tokens))
;;

let output_type_list tlexero tokens =
  List.iter (fun (number, token) ->
    Printf.fprintf tlexero "    | %s\n" token
	    ) tokens
;;

let output_token_int tlexero tokens =
  List.iter (fun (number, token) ->
    Printf.fprintf tlexero "    | %s -> %d\n" token number
	    ) tokens
;;

let output_int_string tlexero tokens =
  List.iter (fun (number, token) ->
    Printf.fprintf tlexero "    | %d -> \"%s\"\n" number token
	    ) tokens
;;

let output_lexicon tlexero lexicon =
  let first = ref true in
  List.iter (fun (token, alias) ->
    Printf.fprintf tlexero "%s    (\"%s\", %s)" (if !first then "" else ";\n") alias token;
    first := false;
	    ) lexicon;
  Printf.fprintf tlexero "\n"
;;

let output_symbols tlexero symbols =
  Printf.fprintf tlexero " | \";\" { adj lexbuf; SEMICOLON}\n";
  List.iter (fun (token, alias) ->
    Printf.fprintf tlexero "| \"%s\" { adj lexbuf; %s }\n" alias token
	    ) symbols
;;

let output_mll symbols lexicon tokens input output =
  let tlexeri = open_in input in
  let tlexero = open_out output in
  output_string tlexero
    "(* This file is automatically generated from src/{tparser.gr,tlexer.in,make_tll.ml}.
    DO NOT EDIT THIS BY HAND. *)\n\n";
try
  while true do
    let line = input_line tlexeri in
    output_string tlexero line;
    output_char   tlexero '\n';
    match line with
    | "PUT TYPE LIST *)" -> output_type_list tlexero tokens
    | "PUT TOKEN TO INT *)" -> output_token_int tlexero tokens
    | "PUT INT TO STRING *)" -> output_int_string tlexero tokens
    | "PUT LEXICON *)" -> output_lexicon tlexero lexicon
    | "PUT SYMBOLS *)" -> output_symbols tlexero symbols
    | _ -> ()
  done
with End_of_file -> (close_in tlexeri; flush tlexero; close_out tlexero)
;;

let main () =
  let (symbols, lexicon, tokens) = analyze_gr "src/trealparserin.gr" in
  output_mll symbols lexicon tokens "src/tlexer.in" "src/tlexer.mll";
;;

main ()
