# besm2_fmt: the Oberon-2 port, rewritten on Ropes, built with poc

This repo, `pobesm2_fmt2`, is obesm2_fmt2
(`~/Repos/RPG/Tools/obesm2_fmt2`) ported from voc, Vishap Oberon, to
poc, the Peaseblossom Oberon Compiler. The port is the next section.
Sections 1 to 5 and the rest are obesm2_fmt2's plan, kept as its
history: where they say voc, `VOC_OBERON_MODULES`, olibfyaml, `CFLAGS`
or `test/regs.sh`, that is how obesm2_fmt2 was built, not this repo.

## Port to poc `[done]`

Started 2026-10-05 from obesm2_fmt2 `c37918a`, with poc 0.2.0 (the
Peaseblossom RPM, `peaseblossom-0.2.0-1.fc44`), following polibfyaml's port of olibfyaml.

**Target:** the same program, built by the installed poc under `-OC`,
with `Ropes.Mod`, `ArgParser.Mod` and polibfyaml's modules (`FyThin.Mod`,
`FyThin.c`, `Fyaml.Mod`, `FyamlStreams.Mod`) from `POC_OBERON_MODULES`
(default `/usr/local/sw/versions/oberon/poc/include`) in place of
`VOC_OBERON_MODULES` and an olibfyaml checkout (since replaced by
compiled poc libraries: the next section). The executable is
`pobesm2_fmt2`; its messages still say `besm2_fmt`.

**Acceptance criteria:** obesm2_fmt2's, unchanged: `make test` (unit
tests, `test/cli.sh`, every golden file), and `make compare` against
both the voc build of obesm2_fmt2 and the Buffer port, byte for byte on
standard output and standard error, and on exit status. Plus `make
valgrind` clean.

**What changed:**

- **The code.** One change: `Besm2Fmt`'s `strerror` was a voc code
  procedure (inline C); it is now an external procedure,
  `PROCEDURE ["C", "strerror"] strerror(e: SYSTEM.INT32): SYSTEM.ADDRESS`,
  with C's `int` written `SYSTEM.INT32` as poc's runtime does. It is
  unexported. (polibfyaml's AGENTS.md says poc 0.1.0 couldn't call an
  exported external procedure from another module; 0.2.0 can, confirmed
  with a throwaway program, so that no longer matters.) Everything else, `Platform`,
  `Files`, `Out`, `Err`, `Strings`, `Modules`, compiled unchanged:
  poc's runtime keeps voc's interfaces.
- **`rtl/Args.Mod` is gone.** It stood in for voc's `Args`, which is
  only in voc's `-O2` library; poc-rtl has `Args` (and `Err`) for both
  models.
- **`CFLAGS` and `test/regs.sh` are gone.** They kept gcc off the
  callee-saved registers because voc's collector couldn't see a pointer
  held only in one (the Buffer port's `VOC-GC-BUG.md`). poc's collector
  spills the registers into its own frame (`llvm.eh.unwind.init`)
  before it scans the stack (poc's `rtl/llvm/GarbageCollectedHeap.Mod`).
  `test/cli.sh`'s 1000-copy check, which caught the voc bug, still
  passes.
- **The makefile.** poc builds each program from its main module,
  compiling every imported module from source into `obj/`, so the
  per-module rules, the import-order dependencies and `obj/cflags` are
  gone, and the makefile is `.NOTPARALLEL` (every program rewrites the
  shared modules' files in `obj/`). libfyaml's flags reach poc as
  `-c-flag` and `-link`.
- **`make compare`** runs `test/compare.sh` against the voc build of
  obesm2_fmt2 (`VOC_BESM2_FMT2`) as well as the Buffer port
  (`OLD_BESM2_FMT`). **`make benchmark`** and **`make perfcompare`**
  measure this build against the voc build (`tools/benchmark.sh`
  relabelled; `PERFORMANCE-POC-VS-VOC.md`); `tools/perfdata.sh` is
  unchanged, still identical to the other ports' copies, and is given
  `BESM2_FMT=./pobesm2_fmt2`. obesm2_fmt2's `PERFORMANCE-*.md`
  measured voc builds, so they stay in obesm2_fmt2.
- **Valgrind** uses polibfyaml's `poc-gc.supp` and `libfyaml.supp`
  from its checkout (`POLIBFYAML`), and its `vg-reachable.sh` for the
  still-reachable check: every still-reachable block must have been
  allocated by `GarbageCollectedHeap` (voc's check counted
  `Heap_NewChunk` records). One more suppression, in
  `test/poc-gc.supp`: 18 of the 138 runs had "Use of uninitialised
  value of size 8" in `GarbageCollectedHeap.DrainMarkStack`, which
  `--track-origins=yes` traced to a stack allocation in
  `Besm2Grid.ProcessEntity`: a never-written stack word, taken by the
  conservative scan for a pointer and traced. polibfyaml's file
  suppresses the same thing in `MarkCandidate` only; its tests never
  reached `DrainMarkStack` with one.
- **Comments** that described voc's behaviour now say what poc does,
  where it differs: poc zeroes locals; poc's `Out` buffers nothing;
  poc runs finalizers at `Platform.Exit`; poc's `Files` reads a
  rewritten file afresh, where voc's cached it by inode (confirmed with
  a throwaway program; `TestLayout` keeps a file per capture anyway).

**Results** (2026-10-05): `make test` passes; `make compare` gives
1,160 identical runs against each of the voc build and the Buffer
port; `make valgrind` passes its 138 runs. A short `make benchmark`
(`BENCH_N=50`, one run per throughput cell) had the poc build 0.23 to
0.43 of the voc build's time on the 2,000-entity inputs, and 0.49 to
0.86 per invocation, with the same peak memory; it was not repeated,
so take it as a direction, not a measurement (`make perfcompare` is
the careful one).

`make perfcompare` (2026-10-05, default settings, `PERFORMANCE-POC-VS-VOC.md`)
confirms it: identical output in every case, and the poc build does
0.42 of the voc build's instructions and takes 0.42 of its CPU time
(geometric means over every case and format), with the same peak
memory. Grid tables gain most (0.25 of the instructions), terse least
(0.58); on the big inputs CPU time is 0.21 to 0.44 of voc's. Not
investigated: voc compiles C without optimization (obesm2_fmt2's
`CFLAGS` also kept gcc off five registers), where poc's clang
optimizes at `-O2` by default.

**Source being rewritten:** the Oberon-2 `besm2_fmt` in
`~/Repos/RPG/Tools/obesm2_fmt` ("the Buffer port" below; about 2,440
lines in `src/`), a port of the Ada `besm2_fmt`, itself a port of
`besm2-rst.scm`. It reads YAML files of BESM 2E entities and writes
each as reST grid tables (the default), terse (`-t`), an h-m-m outline
(`-H`) or raw ms/tbl (`-m`). All of its text handling goes through its
own `Besm2Str.Mod`: `String = POINTER TO ARRAY OF CHAR`, a growable
`Buffer`, and a `List` of strings.

**Target:** the same program with `Besm2Str.Mod` gone and every string
a `Ropes.Rope`, from `Ropes.Mod` (`~/Repos/Oberon/Ropes`). Everything
else is kept: voc under `-OC`, `ArgParser`, olibfyaml, the module
layout, the tests, the executable's name.

**Acceptance criteria:**

1. `make test` passes: every golden file in `test/golden/` (generated
   from the Ada binary, and copied here unchanged) still matches byte
   for byte, and `test/cli.sh` passes unchanged.
2. `make compare` passes: standard output, standard error and exit
   status are identical to the Buffer port's binary for every fixture
   under every flag set. This covers what the golden files don't, the
   error messages. (A defect in the Buffer port found here was fixed
   there too: step 7.)

The design of the program itself (the entity records, the four
backends, the error and exit-status rules, the quirks copied from the
Ada version) isn't repeated here. It is in the Buffer port's
`PLAN.md`, sections 1 to 8, and `ADA-DIFFERENCES.md`, and all of it
still holds. This plan covers only what changes.

## Shared modules as poc libraries `[done]`

Decided with the user 2026-10-05, after the port. The port took
ArgParser, Ropes and polibfyaml as sources from `POC_OBERON_MODULES`,
so poc compiled all of them again on every build. Now each of those
repos' `install` builds a poc library (`poc -library`), and this repo
links them compiled: `argparser`, `ropes` and `polibfyaml`, each in
its own directory under `POC_OBERON_LIBRARIES` (default
`/usr/local/sw/versions/oberon/poc/lib`), passed to poc with
`-library-path`. (Since 2026-11-02 all of them are in one directory,
`POCLIBDIR`, by default `~/.local/lib/poc`, as every library repo now
installs.) Found while choosing, with poc 0.2.0:

- **A plain `.sym` + `.o` install works too, but has three catches**:
  poc looks for `<Module>.Mod` on the import path before `.sym`/`.o`,
  so the source must not be installed beside them (with `Ropes.Mod`
  back, poc compiled Ropes again); FyThin's C part is a separate
  `FyThin.c.o`, without which the link fails ("undefined reference to
  `FyThin.-open-errno`"); and a directory holds one size model ("out/
  Ropes.o was compiled for -OC, and this is -O2"), where Ropes' and
  ArgParser's own programs are `-O2` and this one `-OC`. A library has
  none of these: poc puts each model in `<triple>/<O2|OC>/`, the
  archive holds `FyThin.c.o`, and the manifest lets poc check the
  libraries against each other.
- **One directory per library**, because poc always takes a module
  from a library on the library path, never from source: with every
  library in one directory, Ropes' `RopeTool`, which needs
  `argparser`, would have linked the installed `ropes` instead of the
  checkout it tests.
- **A library doesn't record libfyaml's link flags**: `-link -lfyaml`
  is still given. It does record the poc version, and another poc
  refuses it, so the libraries are installed again after a poc upgrade.
- **Only the archive, shared object, manifest, `.sym` and `.owner`
  are installed.** `-library` also writes each module's `.o` and `.ll`
  (and `FyThin.c.o`), but a program needs none of them: with them all
  removed, the program built statically, with `-shared-libraries` and
  with `-lto`, and the first two matched the voc build on every
  `compare.sh` run. poc's own `poc-rtl` ships without them, and `poc
  -install-library`, which the three repos' `install` now use to copy
  a library from their build directory, leaves them out: 640 KB
  installed instead of 2.2 MB.
- Results: `make test`, `make compare` (1,160 runs against each
  oracle) and `make valgrind` pass, linking the libraries; a build of
  the program from scratch takes 0.63 s, from 1.3 s. ArgParser
  (`test-poc`, 73), Ropes (72) and oberon-tools (188), whose `OModPath`
  also takes `argparser` now, pass too. The source copies in
  `/usr/local/sw/versions/oberon/poc/include` were removed.

## 1. What `Ropes` replaces, and what it doesn't have

| Buffer port (`Besm2Str`) | Here |
|---|---|
| `String` (`POINTER TO ARRAY OF CHAR`, 0X-terminated) | `Ropes.Rope` |
| `Of(s)` | `Ropes.FromString(s)` |
| `Empty()`, and `""` as a value | `NIL`: the empty rope **is** NIL (see §2) |
| `Length(s^)` (bytes) | `Ropes.Length(r)` |
| `s^ = "ACV"` | `Ropes.EqualString(r, "ACV")` |
| `Concat`, `Concat3`, `Buffer` with `Add`/`AddChar`/`Get` | `Ropes.Cat`, `Ropes.AppendChar`; `Besm2Text.Add` for a literal |
| `Repeat(c, n)`, `AddRepeat` | `Ropes.Make(n, c)` |
| `AllOneLine`/`SpaceToNewline` loops in the backends | `Ropes.Map` with a module-level `Mapper` |
| `WordWrap`'s character loop | `Ropes.FindToken` with a `CharSet` of the break characters, `Ropes.Substring` |
| `Besm2Out.Str(s)` | `Besm2Out.Rope(r)`, leaf by leaf with `Ropes.IterateChunks` |

What `Ropes` doesn't have goes in one small module, **`Besm2Text`**,
which imports only `Ropes`:

| Needed | Why `Ropes` alone won't do | `Besm2Text` |
|---|---|---|
| A decimal integer as a rope | No such operation | `Int`, `AddInt` |
| Width in UTF-8 characters | `Ropes.Length` counts bytes | `DisplayLength`: `Ropes.CountSet` with the set of bytes that aren't continuation bytes |
| Trim of blank, tab, LF, CR | `Ropes.Trim` also strips form feed (0CX), which the Ada version and the Buffer port keep | `Trim`: `IndexSet`/`RIndexSet` with that set, then `Substring` |
| The Ada `To_Lower` fold for sorting | `Ropes.CompareNoCase` folds ASCII only; the Ada fold also moves bytes `C0X..DEX` | `FoldCI` (`Ropes.Map`), `LessCI` (`Ropes.Compare` of the folded ropes) |
| A growable list of strings, `Join`, a stable sort | `Ropes.Pieces` is a fixed array from `SplitArray` | `List`, `Clear`, `Append`, `Join`, `SortCI` |
| Text for `Err.String`, `Platform.New`, `FyamlStreams.OpenFile` | `Ropes.ToString` needs the caller to size the array | `Chars(r)`: a heap array of exactly `Length(r) + 1`, filled by `ToString` |
| Appending a literal | It is `r := Ropes.Cat(r, Ropes.FromString("..."))` each time, about 60 times | `Add(VAR r; s)` |

`Besm2Text` is not `Besm2Str` under another name: it has no string
type and no buffer of its own, and callers use `Ropes` directly for
everything `Ropes` has.

## 2. The empty rope is NIL

This is the one change that isn't mechanical. The Buffer port uses
NIL for "absent" and `""` for "present but empty", as the Ada version
uses `Has_Name` and friends, and the output differs: `name: ""` writes
an empty header line and an empty underline, no `name` writes neither.
With ropes both are NIL. So each place that tested a pointer gets an
explicit flag:

| Buffer port | Here |
|---|---|
| `e.name # NIL`, `e.tagline # NIL`, `e.description # NIL`, `e.size # NIL` | `e.hasName`, `e.hasTagline`, `e.hasDescription`, `e.hasSize` (the Ada `Has_*` again) |
| `Besm2Config.hmmRoot # NIL`, `outputFile # NIL` | `Besm2Config.hasHmmRoot`, `hasOutputFile` (`-R ""` writes an empty root line; `-o ""` fails to create `""`) |
| `Besm2RawMs.Row(a, b, c)` with `c = NIL` for two columns, `TextRow(a, b, text)` with `b = NIL` | `Row2`/`Row3`, `TextRow2`/`TextRow3` |
| `Load` returning `msg # NIL` or `yerr # NIL` | Unchanged: `yerr = NIL` means the error is `msg`, which is never empty |
| `Length(details^) > 0` | `details # NIL` |

A new fixture, `test/data/empty-strings-2e.yaml` (`name: ""`,
`tagline: ""`, `description: ""`, `size: ""` and more), with golden
files from the Ada binary in all four formats, pins this down; no
existing fixture had an empty string there. It also found a defect in
the Buffer port (step 7).

Locals aren't zeroed by voc, so a rope built up in a local variable
starts with `r := NIL`, as a `Buffer` started with `Reset`.

## 3. Where `Ropes.Mod` comes from

(For voc; this repo links the poc library `ropes`: see "Shared modules
as poc libraries".)

From `VOC_OBERON_MODULES` (default
`/usr/local/sw/versions/oberon/voc/include`), through the makefile's
`vpath`, like `ArgParser.Mod` and `Err.Mod`: that is how the Ropes
repo's `AGENTS.md` says other repos get it (`make install` there), and
the installed copy is identical to the checkout's today. It is
compiled into `obj/` with this repo's `-OC` and `CFLAGS`. Nothing else
from `~/Repos/Oberon/Ropes` is needed: `Ropes` imports only `Files`,
`In` and `Out`, all in voc's `-OC` library.

`Ropes` is developed under voc's default size model, where `LONGINT`
is 32 bits; here it is 64 (`-OC`). Its length arithmetic guards
against overflow with `MAX(LONGINT)`, so the wider type only loosens
the limits. Checked before relying on it: see step 1.

## 4. Module layout

```
obesm2_fmt2/
  rtl/Args.Mod          -- unchanged
  src/
    Besm2Text.Mod       -- NEW: what Ropes lacks (§1)
    Besm2Config.Mod     -- hmmRoot, outputFile as ropes, with has* flags
    Besm2Out.Mod        -- Rope(r) replaces Str(s)
    Besm2Layout.Mod     -- Pad, WordWrap, rows and emphasis over ropes
    Besm2Entities.Mod   -- fields are ropes; hasName and friends
    Besm2Terse.Mod, Besm2Grid.Mod, Besm2Hmm.Mod, Besm2RawMs.Mod
    Besm2Cli.Mod        -- files is a Besm2Text.List
    Besm2Fmt.Mod        -- main module
  test/
    TestText.Mod        -- replaces TestStr.Mod
    TestLayout.Mod, TestEntities.Mod   -- same checks, over ropes
    Check.Mod, data/, golden/, golden.cases, golden.sh, cli.sh, regs.sh   -- unchanged
    compare.sh          -- NEW: against the Buffer port's binary (make compare)
  tools/benchmark.sh    -- adds the Buffer port as a third column
  GNUmakefile
```

Compile order: `Args`, `Err`, `ArgParser`, `FyThin`, `Fyaml`,
`FyamlStreams`, `Ropes`, `Besm2Text`, `Besm2Config`, `Besm2Out`,
`Besm2Layout`, `Besm2Cli`, `Besm2Entities`, `Besm2Terse`, `Besm2Grid`,
`Besm2Hmm`, `Besm2RawMs`, then `Besm2Fmt -m`.

## 5. Build order

Each step ends with its tests passing and this file updated.

1. [done] **Scaffolding.** Copied the makefile, `rtl/`, the tests,
   fixtures and golden files from the Buffer port; added `Ropes` to
   the shared modules, with a check that `Ropes.Mod` is in
   `VOC_OBERON_MODULES`. Findings:
   - **`Ropes` works under `-OC`.** `RopeTest.Mod`, built from the
     Ropes checkout with `voc -OC` and the makefile's `CFLAGS`, passes
     242 of 242 checks.
   - `Ropes.Mod` in `VOC_OBERON_MODULES` is identical to the checkout's.
2. [done] **`Besm2Text`** with `TestText` (46 checks): the `TestStr`
   checks that still mean something, plus NIL (the empty rope) in every
   operation, ropes of several leaves (`Ropes.Depth` > 0: built from
   pieces longer than `ShortLeafLength`, since `Cat` merges shorter
   ones) for `DisplayLength`, `Trim`, `LessCI` and `Chars`, and checks
   that `Ropes.Trim` and `Ropes.CompareNoCase` really do differ from
   what is needed (§1), so the reason for `Besm2Text.Trim` and `FoldCI`
   stays pinned down.
3. [done] **`Besm2Config`, `Besm2Out`, `Besm2Layout`** with `TestLayout`
   (44 checks: all 39 of the Buffer port's, unchanged in what they
   expect, plus whitespace-only wrapping, a word that crosses a leaf
   boundary, a NIL cell, and bold and italics of the empty rope).
   `TestLayout` reads its capture files back with
   `Ropes.ReadLineRider`. `WordWrap` finds words with
   `Ropes.FindToken`; `Pad` is `Cat` with `Ropes.Make` (not
   `Ropes.Head`, which truncates and counts bytes); `Besm2Out.Rope`
   writes leaf by leaf with `Ropes.IterateChunks`.
4. [done] **`Besm2Cli`**: `files` is a `Besm2Text.List` (an empty
   argument is a NIL item, still a file name); `-u`/`-U` check their
   argument with `Strings.Length`.
5. [done] **`Besm2Entities`** with `TestEntities` (54 checks: the Buffer
   port's 52, with NIL tests turned into `has*` tests, plus an empty
   name, a tagline that trims to nothing, and details that trim to
   nothing). The sort folds each name once (`FoldCI`) and compares
   keys, instead of folding both names at every comparison.
6. [done] **The four backends and `Besm2Fmt`.** Everything compiled on
   the first build, and all 282 golden files and all 39 `cli.sh` checks
   passed on the first run. `ProcessEntity`'s item text is built with
   `Ropes.Cat`/`AppendChar`/`Besm2Text.Add`; `AllOneLine` and
   `SpaceToNewline` are `Ropes.Map`; raw ms has `Row2`/`Row3` and
   `TextRow2`/`TextRow3` (§2); `Besm2Fmt` writes `strerror`'s text
   straight to `Err` instead of building a string.
7. [done] **`test/compare.sh` (`make compare`) and the empty-string
   fixtures.** `compare.sh` runs both programs on every fixture under
   every flag set in `golden.cases` and on standard input, then several
   files, `-o`, `-R ""`, `-o ""`, an empty file name, and the command
   line errors: 1,072 runs (1,116 once the fixture below was no longer
   skipped), all identical in standard output, standard error and exit
   status. Two new fixtures, each with golden files
   from the Ada binary in all 37 per-fixture cases (356 golden files
   now; the 282 old ones regenerated unchanged but for the five
   several-files cases, which now include the new fixtures):
   - `empty-strings-2e.yaml`: `name`, `tagline`, `description` and
     `size` present but empty, a tagline and details of blanks only,
     an empty `effective`, empty stat names and values. The Ada binary,
     the Buffer port and this program agree on all of it, in every
     format.
   - `empty-items-2e.yaml`, for **a defect in the Buffer port found
     here**: `alternatives: [""]` or `specialisations: [""]` (a list
     whose items are all empty). The Ada version and `besm2-rst` write
     `Attack Combat Value ()` in the grid and raw ms formats, testing
     whether the list is empty; the Buffer port tested whether the
     joined text was empty and wrote `Attack Combat Value`. With ropes
     the joined text is NIL either way, which is what exposed it. This
     program follows the Ada version (`WithList` in `Besm2Grid` and
     `Besm2RawMs`). Terse and h-m-m already tested the list in both.
     Until the Buffer port was fixed too (its PLAN.md, step 12, the
     same `WithList`, and the same two fixtures), `compare.sh` skipped
     this fixture; now it doesn't, and the two repos' golden
     directories are identical.
   - **The checks bite.** Planted one at a time, each of these bugs was
     caught: folding ASCII only (1 unit check, 42 golden cases, 48
     compare runs fail), trimming form feeds (1 unit check), measuring
     width in bytes (6, 70, 103), an unstable sort (1, 1, 48), testing
     `e.name # NIL` instead of `e.hasName` in the grid format (golden
     11, compare 14), and rewording an error message (compare 224;
     the golden files, which leave out standard error for bad input,
     and the unit tests don't see it).
8. [done] **`make valgrind`, `make benchmark`, README.**
   - **`make valgrind`**: 133 runs, no errors, nothing lost. The check
     that nothing is still reachable but voc's heap chunk had to
     change: on the run with every fixture as arguments, voc's heap
     grows a second 256,024-byte chunk (allocated under
     `Ropes.StartWalk`, from the sort), which the Buffer port never
     needed. That isn't a leak, so the makefile now requires every
     still-reachable record to come from `Heap_NewChunk` instead of
     exactly one record.
   - **`make benchmark`** (`PERFORMANCE-COMPARISON.md`, now with the
     Buffer port as a third column): per invocation, the two ports are
     within 5 to 16% of each other; on 2,000 entities, ropes are faster
     than buffers in 6 of 8 cases (0.49 to 0.85 of the time) and slower
     in 2 (1.09, 1.22), and still 2 to 3 times the Ada binary. These
     are single runs, and the Buffer port's own figures moved by up to
     2.4 times between its report and this one (grid, 2,000
     documents), so read them as "about the same speed", not as a
     ranking. Peak memory is the same.
   - `make rst` builds the same 42 files as the Ada binary's output for
     the same flags. `make install` checked with `DESTDIR` only.
   - README rewritten for this repo.

9. [done] **Performance against the Buffer port: `make perfdata` in both
   repos, `make perfcompare` here** (`PERFORMANCE-ROPES-VS-BUFFERS.md`).
   `tools/perfdata.sh`, identical in both repos, measures one program
   on inputs made from `enyon-boase-2e` and `synthetic-2e`: each alone
   ("small", 31 runs), and 2,000 copies of its entities as one document
   ("doc") and as 2,000 documents ("docs"), 7 runs each, in all four
   formats. Each run is pinned to one performance core under
   `perf stat`: user-mode instructions (steady to about 0.03%), CPU
   time and wall time, as median, minimum and maximum, plus peak memory
   from one run and a checksum of the output. `tools/perfcompare.sh`
   refuses data from different inputs or format versions, confirms the
   outputs are identical, and writes the tables and geometric means.
   A full run takes about five minutes. The first one (2026-09-30):
   - **On big inputs ropes are faster**: 0.48 to 0.80 of the Buffer
     port's instructions in 13 of the 16 big cases, about the same in
     `docs` grid and h-m-m of `enyon-boase` (1.02, 1.10), and slower
     only in h-m-m of `docs-synthetic` (1.15). CPU time follows
     (0.48 to 0.85; 1.07 to 1.21 for the same three).
   - **On one small file ropes are slower**: 1.09 to 1.11 times the
     instructions in most formats, but 2.8 to 4.3 times in grid (both
     fixtures) and in h-m-m and raw ms of `synthetic` -- about 2 times
     the CPU time, 0.6 to 1.6 ms more.
   - **Garbage collection explains both.** Counting `Heap_GC` calls
     with gdb: on one small file the rope program allocates just enough
     more to trigger one to three collections where the Buffer port
     has none or one, and each sweeps voc's whole first heap chunk, a
     few million instructions -- a threshold effect, not a cost per
     entity. On the big inputs it is the other way round: terse of
     `doc-enyon-boase` collects 255 times with ropes and 672 times with
     buffers, since a `Buffer` allocated a 64-byte array at every
     `Reset` and copied its text again at every `Get`, where ropes
     share their pieces. The GC dominates both programs' own time
     (the Buffer port's PLAN.md, step 11, found libfyaml and `malloc`
     the rest).
   - Peak memory is the same within noise: voc's heap dominates it.
   - Overall, geometric mean of all 24 cases: 0.97 of the
     instructions, 0.89 of the CPU time.

10. [done] **Caught up with the Buffer port's step 14** (obesm2_fmt
    a18b73a, 289ef95), which this repo was forked before: the Ada
    version fixed the defects the ports were written to avoid.
    - `test/golden.cases`: the `shape-*` fixtures are in the `bad`
      globs, since the Ada version now reports them in the ports'
      words, and `sort-ties` is an `ada` case, with a grid case, since
      the Ada sort is stable now: 363 golden files, identical to the
      Buffer port's at 52d7b20.
    - `test/cli.sh`: a directory given as a file is reported (fixed in
      olibfyaml, `FyThin.OpenErrno`; this binary needed rebuilding to
      get it), and a pipe given as a path is read whole.
    - The comments, here and in the fixtures, that described the Ada
      defects as current.
    - `make compare` against the Buffer port built at 52d7b20: 1,116
      runs, all identical.

11. [done] **Six `besm2-rst` quirks fixed, as in the Buffer port**
    (its step 15 and ADA-DIFFERENCES.md, 5.1; besm2_fmt's QUIRKS.md):
    `48154ad` for items 1 to 3 (the `-R` line into the `-o` file, a bad
    entity skipped and the run exiting 1, `--help` exiting 0, and the
    golden files' `==== exit 1 ====` line), `4703413` for items 4 to 6
    (`-p` in grid and raw ms, a blank line after `.TE`, the TOTAL row
    always). Each with golden files from the Ada version at the
    matching commit (`bf18fa4`, `afb25ce`), identical to the Buffer
    port's at `5a9ff04` and `3be8f1e`, and `make compare` against the
    Buffer port built at those commits: 1,116 runs, all identical.

## Deliberate differences from the Buffer port

None. The one there was (step 7) was a defect in the Buffer port, and
it has been fixed there the same way. A new one needs an entry here
and a `skip` in `test/compare.sh`.

## Open questions

- **Should `Besm2Text`'s general parts move into `Ropes`?** `Int`, a
  UTF-8 character count, a rope list with `Join`, and a `Trim` that
  takes a `CharSet` aren't specific to BESM. That is a change to the
  Ropes repo (and its Ada twin's conventions), so it needs the user's
  go-ahead.
- ~~**Does this repo replace `obesm2_fmt` or sit beside it?**~~
  Decided (2026-09-30): it sits beside it for now. So this repo keeps
  pointing at `obesm2_fmt` for `ADA-DIFFERENCES.md`, `VOC-GC-BUG.md`
  and the history in its `PLAN.md`, rather than copying them, and the
  Buffer port stays the oracle for `make compare`. Revisit if this repo
  is ever to replace it; those documents would then move here.
