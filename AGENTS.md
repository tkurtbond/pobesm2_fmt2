# AGENTS.md

Working notes for an agent in this repo, which holds `besm2_fmt`, an
Oberon-2 program (compiled with poc, the Peaseblossom Oberon Compiler)
that reads YAML files describing BESM 2nd Edition characters, templates
and items, and writes them as reStructuredText (grid tables, terse, raw
ms/tbl) or as an h-m-m outline.

It is obesm2_fmt2 (`~/Repos/RPG/Tools/obesm2_fmt2`, "the voc build"),
ported from voc, Vishap Oberon, to poc: see PLAN.md, "Port to poc".
obesm2_fmt2 is a rewrite of the Oberon-2 port in
`~/Repos/RPG/Tools/obesm2_fmt` ("the Buffer port"), with that port's
`Besm2Str.Mod` removed and every string a `Ropes.Rope`. The Buffer port
is itself a port of the Ada `besm2_fmt`, which is a port of
`besm2-rst.scm` from [besm-tools](https://github.com/tkurtbond/besm-tools).

See PLAN.md for the port to poc, then obesm2_fmt2's plan: what changed
from the Buffer port, the module layout and the build order. The design
of the program itself, and every known way the Ada version differs, are
in the Buffer port's `PLAN.md` and `ADA-DIFFERENCES.md`; they still hold
and aren't copied here. This file is operational notes, not a design
doc. Keep this repo and obesm2_fmt2 in step: a change to the program or
its tests belongs in both.

## Reference material

| What | Where |
|---|---|
| The voc build, ported here | `~/Repos/RPG/Tools/obesm2_fmt2/` (`PLAN.md`, `PERFORMANCE-*.md`) |
| Its binary (an oracle for `make compare`) | `~/Repos/RPG/Tools/obesm2_fmt2/obesm2_fmt2` (build with `make` there) |
| The Buffer port | `~/Repos/RPG/Tools/obesm2_fmt/` (`src/`, `PLAN.md`, `ADA-DIFFERENCES.md`, `VOC-GC-BUG.md`) |
| Its binary (the other oracle for `make compare`) | `~/Repos/RPG/Tools/obesm2_fmt/obesm2_fmt` (build with `make` there) |
| Ropes | `~/Repos/Oberon/Ropes/` (`AGENTS.md`, `Ropes.Mod`, `RopeTest.Mod`, `pocGNUmakefile`); installed copy in `$POC_OBERON_MODULES` |
| Ada program | `~/Repos/RPG/Tools/besm2_fmt/` |
| Ada binary (the oracle for `make golden`) | `~/Repos/RPG/Tools/besm2_fmt/besm2_fmt` |
| Original Scheme binary | `~/local/bin/besm2-rst` (on `PATH`) |
| ArgParser (command-line parsing) | `~/Repos/Oberon/ArgParser/`; installed copy in `$POC_OBERON_MODULES` (default `/usr/local/sw/versions/oberon/poc/include`) |
| polibfyaml (YAML) | `~/Repos/Oberon/polibfyaml/` (`AGENTS.md`, `src/`, `test/poc-gc.supp`, `test/vg-reachable.sh`); installed copies of `src/` in `$POC_OBERON_MODULES` |
| poc | installed from the Peaseblossom RPM: `/usr/bin/poc`, its runtime library `poc-rtl` under `/usr/lib/poc` |
| poc source and runtime | `~/Repos/Oberon/Peaseblossom` (`doc/users-guide.md`, section 11 "Coming from voc"; the runtime in `rtl/llvm/`) |

Read the Ropes, polibfyaml and ArgParser `AGENTS.md` files before
working around any of those libraries.

## Build / test

```sh
make            # obj/ (poc output) and ./pobesm2_fmt2
make test       # unit tests, test/cli.sh, test/golden.sh check
make compare    # stdout, stderr and status against the voc build and the Buffer port
make golden     # regenerate test/golden/ from the reference programs
make valgrind   # the program under valgrind over every fixture and path
make benchmark  # timing against the Ada binary and the voc build
make perfdata   # measure this program alone: build/perfdata.tsv
make perfcompare  # perfdata here and in obesm2_fmt2, then PERFORMANCE-POC-VS-VOC.md
make rst        # build/*.gen.rst from test/data/*-2e.yaml
make hmm        # build/*.gen.hmm, h-m-m outlines from the same fixtures
make pdf        # build/*.ms.pdf from those (pandoc, --template=tkb)
make install    # to $(PREFIX)/bin, default ~/local/bin (DESTDIR for staging)
make uninstall
make clean      # rm -rf obj pobesm2_fmt2 build
make testclean  # rm -rf build
make print-VAR  # show a makefile variable
```

- **Don't run `make install` with the default `PREFIX` unless asked**:
  it puts `pobesm2_fmt2` in `~/local/bin`, beside the installed Ada
  `besm2_fmt`. Check the target with `make install DESTDIR=<scratch>`.
- **Everything is compiled with `-OC`**, because polibfyaml requires
  it, and poc refuses a `.sym` from the other size model. Under `-OC`,
  `INTEGER` is 32 bits and `LONGINT` 64. `Ropes` is developed under the
  default model (32-bit `LONGINT`) but works under `-OC`: see PLAN.md,
  step 1.
- **Don't copy `Ropes.Mod`, `ArgParser.Mod` or polibfyaml's modules
  into this repo.** poc finds them on its import path, the directories
  of `POC_OBERON_MODULES`, where `make -f pocGNUmakefile install` in
  Ropes and ArgParser and `make install` in polibfyaml put them. A
  change one of them needs is made in its own repo, tested and
  installed there, and needs the user's go-ahead.
- **`Args` and `Err` come from poc's runtime library**, poc-rtl, which
  has them under both size models (voc's `-OC` library lacked `Args`;
  obesm2_fmt2 has a shim for it).
- poc builds a program from its main module, compiling every module it
  imports from source on every build into `obj/` (`-output-dir`), with
  `FyThin.c`, beside the installed `FyThin.Mod`, compiled by clang as
  its part in C. There is no import order to keep and no per-module
  rule: **a new module in `src/` needs nothing in the makefile**, a
  new unit test only its name in `TESTS`. Every program rewrites the
  shared modules' files in `obj/`, so the makefile is `.NOTPARALLEL`.
  libfyaml's `pkg-config` flags reach poc as `-c-flag` and `-link`.
  Add `-verbose` to a poc command to see the clang commands it runs.
- The main module is `Besm2Fmt`, built as `./pobesm2_fmt2`, named for
  this repo so it can be installed beside the Ada `besm2_fmt` and the
  voc builds. Its messages still say `besm2_fmt`, as the Ada version's
  do.
- **`tools/perfdata.sh` is shared**: the Buffer port and obesm2_fmt2
  have identical copies, so all the programs are measured the same
  way; the makefile passes it `BESM2_FMT=./pobesm2_fmt2`. Change all
  copies together (`cmp` them), and bump its `FORMAT_VERSION` when the
  data format changes; `tools/perfcompare.sh` refuses files whose
  versions differ. Compare performance by instruction counts first:
  they barely move between runs, where CPU times on this laptop move
  by 10% or more. `make perfcompare` takes several minutes;
  `PERF_COPIES`, `PERF_RUNS_SMALL` and `PERF_RUNS_BIG` make a quick
  trial run.

## Testing policy

- **Two kinds of oracle.** The golden files (`test/golden/`, from the
  Ada binary, or `besm2-rst` for `scheme` cases) fix standard output.
  `make compare` (`test/compare.sh`) checks standard output, standard
  error and exit status against the voc build of obesm2_fmt2 and the
  Buffer port's binary, over every fixture and every flag set in
  `test/golden.cases`; it is what checks the error messages byte for
  byte. Run both after any change. `make compare` needs both built, so
  it isn't part of `make test`.
- **Regenerate golden files with `make golden`; never hand-edit one.**
  Add a line to `test/golden.cases` for new coverage and review the new
  files before committing them.
- A new behaviour worth testing gets a fixture in `test/data/` and a
  line in the golden flag matrix, not a one-off manual diff. Fixtures
  named `*-2e.yaml` are picked up by every `*-2e` case.
- `test/cli.sh` checks the command line: exit statuses and a line each
  case's output must contain.
- Unit tests (`test/Test*.Mod`) print `ok   - <label>` / `FAIL -
  <label>` and end with `All checks passed.` or `<N> check(s) failed.`,
  exiting 1 on failure. A passing test returns normally rather than
  calling `Platform.Exit(0)` (which skipped finalizers under voc; poc
  runs them).
- **`make valgrind`** must have no errors, nothing lost, and no
  still-reachable block but the collector's own (polibfyaml's
  `test/vg-reachable.sh` checks who allocated each). It uses
  polibfyaml's suppressions, from its checkout (`POLIBFYAML`), and
  `test/poc-gc.supp`, for the conservative stack scan's
  uninitialised-value errors in `DrainMarkStack` (PLAN.md, "Port to
  poc"). Keep suppressions that narrow: an error anywhere else is real
  until shown otherwise (`--track-origins=yes`).
- **Prove a new check can fail**: plant the bug it targets and watch it
  fail.
- **Test ropes of more than one leaf.** `Ropes.Cat` merges leaves up to
  `ShortLeafLength` (16) characters, so a rope built from short pieces
  is often a single leaf and hides a bug in code that walks leaves.

## Working with ropes here

- **The empty rope is NIL.** There is no "present but empty" rope, so
  "absent" needs its own flag: `e.hasName`, `Besm2Config.hasHmmRoot`
  and so on (PLAN.md, section 2). Test emptiness with `r = NIL`.
  Never add a flagless optional string.
- **Start a rope built up in a local with `r := NIL`**, and
  `Besm2Text.Clear` a `List` before using it. poc zeroes locals, but
  voc doesn't, and obesm2_fmt2 shares this code.
- **Use `Ropes` directly for what it has** (`Cat`, `AppendChar`,
  `FromString`, `Length`, `EqualString`, `Make`, `Map`, `Substring`,
  `FindToken`, ...). `Besm2Text` holds only what it lacks: `Add`,
  `Int`/`AddInt`, `DisplayLength`, `Trim`, `FoldCI`/`LessCI`, `List`
  with `Join` and `SortCI`, `Chars`.
- **Not `Ropes.Trim`**: it also strips form feed. `Besm2Text.Trim`
  strips blank, tab, LF and CR, as the Ada version does.
- **Not `Ropes.CompareNoCase`** for sorting names: it folds ASCII only.
  `Besm2Text.FoldCI` is the Ada `To_Lower` byte fold the golden files
  depend on.
- **`Ropes.Length` counts bytes.** Column widths use
  `Besm2Text.DisplayLength`; header underlines use bytes, as the Ada
  version does.
- **Never walk a rope with a `Fetch` per character.** Use
  `Ropes.FindToken`/`IndexSet`/`CountSet`/`Map`/`IterateChunks`.
- **Callbacks (`Ropes.Mapper`, `Ropes.ChunkVisitor`) must be
  module-level procedures**; a nested procedure can't be a procedure
  value.
- **Output is `Besm2Out.Rope(r)`**, never `Ropes.Write` (it goes to
  `Out`, which `-o` can't redirect) and never through `Ropes.ToString`
  into a fixed array (it truncates silently).
- **`Besm2Text.Chars(r)` is for the few places that need an `ARRAY OF
  CHAR`**: `Err.String`, `Besm2Out.ToFile`, `FyamlStreams.OpenFile`.
  Assign it to a variable and pass `v^`: voc won't pass a dereferenced
  function result, `F()^`, as an open array (`err 59`), and the code
  is kept so obesm2_fmt2 can share it.
- **`Ropes.FromString` stops at the first 0X**, so a YAML scalar with
  an embedded 0X is cut short, as in the Buffer port.

## poc / Oberon-2 facts this program depends on

Confirmed here, in polibfyaml, or in poc's runtime source; see their
notes for the details.

- **poc's collector is conservative on the stack and spills the
  registers first** (`llvm.eh.unwind.init`, in
  `GarbageCollectedHeap.Collect`), so voc's register bug (the Buffer
  port's `VOC-GC-BUG.md`) doesn't arise, and obesm2_fmt2's `CFLAGS`
  and `test/regs.sh` aren't needed. `cli.sh`'s 1000-copy check still
  runs the output through many collections.
- **No exceptions.** Loaders return `BOOLEAN` and pass an error back.
  `ASSERT`/`HALT` are for programmer errors only, never bad input.
- **No generics, closures or call chaining.** Use a variable per step.
- **polibfyaml indexes sequences from 0.**
- **`Out` can't be redirected, and writes each call at once** (poc's
  buffers nothing). All program output goes through `Besm2Out`, which
  buffers; flush it before exiting or writing to standard error.
- **Argument evaluation order is unspecified**: don't depend on it
  (obesm2_fmt2 shares the code, and voc compiles to C).
- **`*)` ends a comment anywhere, and `(*` inside a comment opens a
  nested one.**
- **UTF-8 in string literals passes through unchanged.** `CHAR` is a
  byte. **A string literal holds at most 255 characters** (voc: 1024).
- **No string concatenation operator.** A `FOR` loop needs an integer
  control variable, not `CHAR`.
- **Every `CONST`, `TYPE` and `VAR` of a module comes before its first
  procedure**, and a procedure must be declared before it is used.
- **A read-only exported field (`e.stats-`) can't be passed as a `VAR`
  parameter** outside its module; pass it by value.
- **C is called through external procedures**,
  `PROCEDURE ["C", "name"] P(...)`, with C's `int` as `SYSTEM.INT32`;
  voc's inline-C code procedures don't exist in poc. Keep them
  unexported: poc 0.1.0 can't call an exported one from another module
  (polibfyaml's AGENTS.md).
- **`SYSTEM.ADDRESS` is its own type** in poc, not `LONGINT`.
- **A poc runtime trap** prints what happened and exits with poc's own
  status (a failed `ASSERT` 10, NIL dereference 4; poc's users guide,
  section 7), distinct from a module's own `HALT(n)`. `Ropes` HALTs on
  a bad `Fetch` index.

## Conventions

- Keep each module the same as obesm2_fmt2's, but for the port's
  changes (PLAN.md, "Port to poc"), and traceable to the Buffer port's
  module of the same name, and keep its comments that explain *why* something matches
  `besm2-rst.scm` or the Ada version. A comment citing "the Buffer
  port's PLAN.md, step N" means `~/Repos/RPG/Tools/obesm2_fmt/PLAN.md`.
- Comments explain why, and only claim what has been verified. If a
  comment depends on how poc, Ropes, libfyaml or ArgParser behaves,
  test it with a throwaway program in the scratchpad first.
- A difference from the Ada version, new or newly found, is recorded in
  the Buffer port's `ADA-DIFFERENCES.md`: this repo sits beside the
  Buffer port and doesn't keep its own copy (PLAN.md, open questions).
  A difference from the Buffer port is a bug here unless PLAN.md
  records it as deliberate.
- Record decisions and findings in PLAN.md as they happen. Mark a
  finished step `[done]` and strike through an open question once it's
  decided.
