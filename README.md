# pobesm2_fmt2 - obesm2_fmt2 built with poc

`besm2_fmt` reads YAML files describing *Big Eyes, Small Mouth* 2nd
Edition characters, templates and items, and writes them as
reStructuredText (grid tables, terse paragraphs, or groff `tbl` tables
in a raw ms block) or as an [h-m-m](https://github.com/nadrad/h-m-m)
outline.

This is obesm2_fmt2 (`~/Repos/RPG/Tools/obesm2_fmt2`), the rope-based
Oberon-2 `besm2_fmt`, ported from [voc](https://github.com/vishaps/voc),
Vishap Oberon, to poc, the
[Peaseblossom](https://github.com/tkurtbond/peaseblossom) Oberon
compiler. obesm2_fmt2 is a rewrite of the Oberon-2 `besm2_fmt` in
`~/Repos/RPG/Tools/obesm2_fmt` with every string a rope, from
`~/Repos/Oberon/Ropes`. That program is a port of the Ada `besm2_fmt`,
itself a port of `besm2-rst.scm` from
[besm-tools](https://github.com/tkurtbond/besm-tools).

The output is byte-for-byte the same as the Ada binary's (the golden
tests check this) and, standard error and exit statuses included, as
the voc build's and the Buffer port's (`make compare` checks this).

## Usage

```
besm2_fmt [options] [files...]
```

With no files, standard input is read. Output goes to standard output,
or to the file given by `-o`.

| Format | Option |
|---|---|
| reST grid tables (the default) | |
| terse reST paragraphs | `-t`, `--terse` |
| groff `tbl` in a `.. raw:: ms` block | `-m`, `--raw-ms-tables` |
| h-m-m outline | `-H`, `--hmm` |

If more than one format option is given, the last one wins.
`besm2_fmt -h` lists every option. The original's README describes the
input format, the options and the exit statuses; they are unchanged.

## Building

You need:

- poc, with its runtime library `poc-rtl`, on `PATH` (override with
  `POC=`), and clang, which poc runs.
- libfyaml, found through `pkg-config`.
- `ArgParser.Mod` from ArgParser and `Ropes.Mod` from Ropes, installed
  by `make -f pocGNUmakefile install` in each of those repos, and
  polibfyaml's modules, installed by `make install` in
  `~/Repos/Oberon/polibfyaml`, all into `POC_OBERON_MODULES` (default
  `/usr/local/sw/versions/oberon/poc/include`).
- For `make valgrind` only, a checkout of polibfyaml at `POLIBFYAML`
  (default `~/Repos/Oberon/polibfyaml`), for its suppressions.

```sh
make                # ./pobesm2_fmt2
make test           # unit tests, command-line checks, golden-output tests
make compare        # stdout, stderr and status against the voc build and the Buffer port
make valgrind       # the program under valgrind, over every fixture
make benchmark      # time against the Ada binary and the voc build
make perfcompare    # measure this and the voc build the same way; PERFORMANCE-POC-VS-VOC.md
make install        # to $(PREFIX)/bin, default ~/local/bin
make uninstall
make rst            # build/*.gen.rst from the test fixtures
make hmm            # build/*.gen.hmm, h-m-m outlines from the same fixtures
make pdf            # build/*.ms.pdf from those, via pandoc and the tkb ms template
make clean          # everything built; make testclean removes only build/
```

The program is built as `pobesm2_fmt2`, so it can be installed beside
the Ada `besm2_fmt` and the voc builds `obesm2_fmt` and `obesm2_fmt2`;
its messages and usage still call it `besm2_fmt`, as the Ada version's
do. `make install` puts it in `$HOME/local/bin` by default. Set `PREFIX`
(and `DESTDIR` for staging) to install elsewhere.

## Documents

- [AGENTS.md](AGENTS.md): working notes on the build, the tests, ropes
  and poc.
- [PLAN.md](PLAN.md): the port to poc, then obesm2_fmt2's plan: what
  changed from the Buffer port, the build order and the findings of
  each step.
- obesm2_fmt2's `PERFORMANCE-COMPARISON.md` and
  `PERFORMANCE-ROPES-VS-BUFFERS.md` measure the voc build;
  `make perfcompare` here writes `PERFORMANCE-POC-VS-VOC.md`.
