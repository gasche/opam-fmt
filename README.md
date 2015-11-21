opam-fmt
==================

A small script to reformat OPAM configuration files or check that they
are properly formatted.

Usage:
```
opam fmt opam.in --output opam.out        # reformats opam.in into opam.out
opam fmt opam.in                          # reformats opam.in on <stdout>
opam fmt --stdin                          # reformats <stdin> on <stdout>
opam fmt --inplace opam.1 opam.2 ...      # reformats the files in place
opam fmt --check opam.1 opam.2 opam.3 ... # check that reformatting would be a noop
opam --version                            # returns the supported opam file version
```

`opam fmt --check` prints one line of output for each input file that
is not properly formatted (and has a non-zero return code in
this case). In particular, it prints nothing (and returns zero) if the
input(s) are correctly formatted.


## Why reformat `opam` files?

The opam repository is evolves by a mix of manual and automated
changes. Automated scripts will use the parsing and printing function
provided by the OPAM software libraries, but in general parsing and
re-printing a file is not a noop. For example, the fields of the
`opam` file are always printed in a fixed order, which may not be the
one the human author has chosen.

This makes automated changes harder to review, because their diff
(they are sent and discussed as git patches) will contain stuff
related to the change, but also stuff related to this
semantics-preserving reformating. It is harder for authors of
automation scripts to make sure their script is correct, and it is
also harder for human authors to predict what future scripts may
change in their lovingly-edited opam files.

Reformatting your opam files with `opam fmt` guarantees that parsing
and re-printing the file again is a noop. In particular, further
automatically generated changes will be as small as
possible. (They may still contain irrelevant whitespace change: for
example if the change adds an item to a list of dependencies, OPAM may
decide to change the printing from all items on one line to one item
per line.)

## Why not reformat `opam` files?

Parsing and re-printing opam files may lose information. For example,
it is possible to insert comment in OPAM files, and those would be
dropped by the reformatting steps. If you fancy a particular style of
vertical alignment of URLs in your opam file, you may also be
disappointed.

Note however that this means that any automated change will make
a mess of your OPAM file and lose that information. By using `opam
fmt` yourself, you can predict what will be kept and what will be
lost, and be an active rather than passive actor of the demise of your
personal opam-file aesthetics.

Once informed of the exact scope of the disaster by your `opam fmt`
use, you may decide to send a pull request to the OPAM software
libraries to support your personal use-case: docstring comments
attached to specific configuration items, a better ordering of opam
fields, or a nice alignment heuristic. And then it could benefit other
users as well.

Happy reformatting or not.


## `opam fmt` and the `opam-version` field

`opam fmt` is built against a single version of the opam software
libraries. To know which, run the command
```
opam fmt --version
```

Opam files themselves are versioned. It would be rather bad for `opam
fmt` to try to work with files for another version than its own, as it
could either not-understand new features of opam files (if they are
more recent than `opam fmt`), or reformat them in a way unsupported by
older opam versions (if they are older than `opam fmt`).

We use the following strategy:

- if the opam file given to `opam fmt` uses a more recent opam
  version, it will refuse to process it -- just skip it

- if the opam file given to `opam fmt` uses an older opam version, it
  will reformat it but also upgrade it to its own opam version in the
  process

Remark: In theory, it would be possible to build many different
versions of the opam libraries in parallel, and thus support any of
those opam versions to process opam files for the corresponding
version without forcing an upgrade. However, this is currently
impractical for a simple reason: the opam software libraries are
packaged in a way that makes it impossible to installed two different
versions in parallel.
