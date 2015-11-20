native:
	ocamlbuild -no-links -use-ocamlfind fmt.native
	cp _build/fmt.native opam-fmt

byte:
	ocamlbuild -no-links -use-ocamlfind fmt.byte
	cp _build/fmt.byte opam-fmt

clean:
	ocamlbuild -clean
