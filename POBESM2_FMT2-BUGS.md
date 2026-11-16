# pobesm2_fmt2 bugs

Bugs in pobesm2_fmt2's own code, numbered, newest last. A problem that
comes from the YAML binding goes in that binding's bugs file, and one in
libfyaml itself in the binding's `LIBFYAML-ISSUES.md`; this file records
only how it shows here, with a pointer.

When one is fixed, replace its "Status" with "Fix" and "Verified". When
one turns out not to be a bug, say so in its section rather than
deleting it.


## 1. An undefined alias prints nothing and exits 0

**Symptom.** A file with an alias that has no anchor, or a cyclic
reference, prints nothing, and the program exits with status 0. Nothing
after that document is read. besm2_calc_po reports it, `alias.yaml:1:10:
error: invalid alias`, and exits with status 1. Found 2026-11-15 while
porting besm2_cg_po to the web (besm2_cg_web, PLAN.md "Findings").

**Repro** (pobesm2_fmt2 at 78a0fe6, libfyaml 0.8-9.fc44):

```sh
printf -- '- name: *nope\n' > alias.yaml
pobesm2_fmt2 alias.yaml; echo "rc=$?"     # prints only rc=0
```

**Cause.** Not in this program. `ProcessOne` (`src/Besm2Fmt.Mod`) reads
through `FyamlStreams`, which resolves aliases, and the stream ends
quietly with no error: polibfyaml bug 1 (`POLIBFYAML-BUGS.md`), caused
by libfyaml issue 2 (`fy_diag_got_error` isn't set for a resolve
failure; polibfyaml's `LIBFYAML-ISSUES.md`).

**Status.** Open, waiting on the polibfyaml fix. Once it is in, add an
undefined-alias case to the tests here.

## 2. A customizer whose counts-as isn't a scalar halts the program

**Symptom.** A customizer in `enhancements` or `limiters` whose second
item (its counts-as) is a mapping or a sequence stops the program with
`assertion failed (62)` on standard error and status 10, instead of an
error for the file. Found 2026-11-15 while porting besm2_cg_po to the
web (besm2_cg_web, PLAN.md "Findings").

**Repro** (pobesm2_fmt2 at 78a0fe6), `enh.yaml`, which is
`test/data/shape-customizer-short.yaml` with its customizer changed:

```yaml
- name: Good
  stats: [{name: Body, value: 4, points: 8}]
- name: Short
  attributes: [{name: A, level: 1, points: 2, enhancements: [[Foo, {a: 1}]]}]
```

```sh
pobesm2_fmt2 enh.yaml; echo "rc=$?"
```

`limiters: [[Foo, [1]]]` does the same. The Ada besm2_fmt reports

```
besm2_fmt: error processing enh.yaml: /1/attributes/0/enhancements/0/1: not a scalar
```

and exits with status 1.

**Cause.** `Customizer` (`src/Besm2Entities.Mod:403`) calls
`part.IntegerValue` on item 1 without checking that it is a scalar.
`Fyaml.Node.IntegerValue` asserts that (`Fyaml.AssertKind`, 62): the
binding treats a call on the wrong kind of node as a programmer error,
so this is a bug here, not in the binding. Item 0 and the applies-to
items go through `Scalar`, which reports "not a scalar".

**Status.** Open. A likely fix: `IF ~part.IsScalar() THEN RETURN
Fail(part, "not a scalar") END` before the `IntegerValue` call, and a
case in `test/cli.sh` beside the `shape-customizer-short.yaml` one. The
same code is in besm2_cg_po (its bug 1; `besm2_calc_po --check` halts
the same way) and obesm2_fmt2 (its bug 2).
