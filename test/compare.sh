#!/usr/bin/env bash
# Compares this program with the Buffer port's binary (PLAN.md,
# acceptance criteria): standard output, standard error and exit status,
# each separately, for every fixture in test/data under every flag set
# in test/golden.cases, then for standard input, several files in one
# run, and -o.  The golden files fix standard output only; this is what
# checks the error messages byte for byte.  Run from the repo root by
# `make compare`, as test/compare.sh [PROGRAM [REFERENCE]]; prints
# ok/FAIL per run, and exits 1 if any failed.
#
# REFERENCE defaults to $OLD_BESM2_FMT, or else
# ~/Repos/RPG/Tools/obesm2_fmt/obesm2_fmt.

set -u
prog=${1:-./pobesm2_fmt2}
ref=${2:-${OLD_BESM2_FMT:-$HOME/Repos/RPG/Tools/obesm2_fmt/obesm2_fmt}}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
failed=0 count=0

[ -x "$ref" ] || { echo "compare.sh: not executable: $ref (make in the Buffer port)" >&2; exit 2; }

# Fixtures where this program departs from the Buffer port on purpose,
# following the Ada version, each with a PLAN.md entry: none now.
skip=" "

# The flag sets of test/golden.cases, each once, plus none.
mapfile -t flagsets < <(echo; grep -vE '^[[:space:]]*(#|$)' test/golden.cases \
  | awk '{ $1 = $2 = $3 = ""; sub(/^ +/, ""); print }' | sort -u)

# same LABEL IN ARGS...: run both programs on ARGS with standard input
# from IN, in the same directory, and compare.  -o, if used, must name
# "$tmp/o", which is compared too.
same() {
  local label=$1 in=$2; shift 2
  local p st
  for p in new ref; do
    rm -f "$tmp/o"
    if [ $p = new ]; then "$prog" "$@" <"$in" >"$tmp/$p.out" 2>"$tmp/$p.err"
    else "$ref" "$@" <"$in" >"$tmp/$p.out" 2>"$tmp/$p.err"; fi
    st=$?; echo $st >"$tmp/$p.status"
    if [ -e "$tmp/o" ]; then mv "$tmp/o" "$tmp/$p.o"; else rm -f "$tmp/$p.o"; fi
  done
  count=$((count + 1))
  local what=""
  cmp -s "$tmp/new.out" "$tmp/ref.out" || what="$what stdout"
  cmp -s "$tmp/new.err" "$tmp/ref.err" || what="$what stderr"
  cmp -s "$tmp/new.status" "$tmp/ref.status" || what="$what status"
  if [ -e "$tmp/new.o" ] || [ -e "$tmp/ref.o" ]; then
    cmp -s "$tmp/new.o" "$tmp/ref.o" 2>/dev/null || what="$what -o-file"
  fi
  if [ -n "$what" ]; then
    echo "FAIL - $label:$what differ"; failed=$((failed + 1))
    diff "$tmp/ref.out" "$tmp/new.out" | head -10 | sed 's/^/    /'
    diff "$tmp/ref.err" "$tmp/new.err" | head -10 | sed 's/^/    /'
  else
    echo "ok   - $label"
  fi
}

for f in test/data/*.yaml; do
  base=$(basename "$f" .yaml)
  if [[ $skip == *" $base "* ]]; then echo "skip - $base (departs on purpose; PLAN.md)"; continue; fi
  for flags in "${flagsets[@]}"; do
    # $flags is split into words on purpose.
    # shellcheck disable=SC2086
    same "$base [$flags]" /dev/null $flags "$f"
  done
  same "$base on standard input" "$f"
  same "$base on standard input [-t]" "$f" -t
done

# Several files in one run, bad ones among them, and -o.
mapfile -t all < <(ls test/data/*.yaml)
same "every fixture in one run" /dev/null "${all[@]}"
same "every fixture in one run [-m -U ~]" /dev/null -m -U '~' "${all[@]}"
same "every fixture in one run [-H -R Root -S]" /dev/null -H -R Root -S "${all[@]}"
same "every fixture in one run, -o [-t]" /dev/null -t -o "$tmp/o" "${all[@]}"
same "-o, -R to standard output" /dev/null -H -R Root -L 2 -o "$tmp/o" test/data/composite-2e.yaml
same "-R with an empty root" /dev/null -H -R "" test/data/composite-2e.yaml
same "-o with an empty name" /dev/null -o "" test/data/composite-2e.yaml
same "an empty file name" /dev/null test/data/composite-2e.yaml "" test/data/enyon-boase-2e.yaml
same "a missing file" /dev/null nosuch.yaml test/data/composite-2e.yaml
same "-o to a directory that doesn't exist" /dev/null -o /nonexistent/dir/out test/data/composite-2e.yaml
same "-o to /dev/full" /dev/null -o /dev/full test/data/composite-2e.yaml
same "-h" /dev/null -h
same "a bad option" /dev/null --bogus
same "a bad -u" /dev/null -u xx test/data/composite-2e.yaml
same "a bad -w" /dev/null -w 24 test/data/composite-2e.yaml
same "empty standard input" /dev/null

echo "compare.sh: $count runs against $ref"
if [ "$failed" -eq 0 ]; then echo "All checks passed."; else echo "$failed check(s) failed."; exit 1; fi
