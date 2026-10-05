# Performance: the poc build vs the voc build and the Ada besm2_fmt

- Date: 2026-10-05
- CPU: 13th Gen Intel(R) Core(TM) i9-13900HX
- poc: `./pobesm2_fmt2`; voc: `/home/tkb/Repos/RPG/Tools/obesm2_fmt2/obesm2_fmt2`; Ada: `/home/tkb/Repos/RPG/Tools/besm2_fmt/besm2_fmt`
- `BENCH_N`=200, `BENCH_ENTITIES`=2000, `BENCH_SOURCE`=`test/data/enyon-boase-2e.yaml`
- The three programs' outputs were checked to be identical on every
  input and format first.

## Per-invocation time (200 runs of `enyon-boase-2e.yaml`)

| Format | Ada (ms) | voc (ms) | poc (ms) | poc / voc | poc / Ada |
|---|---|---|---|---|---|
| grid | 1.52 | 5.12 | 2.77 | 0.54 | 1.82 |
| terse | 2.46 | 3.35 | 2.79 | 0.83 | 1.13 |
| h-m-m | 2.86 | 2.56 | 2.16 | 0.84 | 0.76 |
| raw ms | 2.74 | 2.78 | 2.60 | 0.94 | 0.95 |

## Throughput: 2000 entities in one document

| Format | Ada (s) | voc (s) | poc (s) | poc / voc | poc / Ada | Ada max RSS (KB) | voc max RSS (KB) | poc max RSS (KB) |
|---|---|---|---|---|---|---|---|---|
| grid | 0.35 | 0.96 | 0.25 | 0.26 | 0.71 | 135132 | 134052 | 134860 |
| terse | 0.22 | 0.43 | 0.19 | 0.44 | 0.86 | 135260 | 134624 | 135060 |
| h-m-m | 0.20 | 0.46 | 0.19 | 0.41 | 0.95 | 136000 | 134316 | 134792 |
| raw ms | 0.22 | 0.46 | 0.19 | 0.41 | 0.86 | 135404 | 134564 | 134348 |

## Throughput: 2000 documents of one entity each

| Format | Ada (s) | voc (s) | poc (s) | poc / voc | poc / Ada | Ada max RSS (KB) | voc max RSS (KB) | poc max RSS (KB) |
|---|---|---|---|---|---|---|---|---|
| grid | 0.34 | 0.91 | 0.20 | 0.22 | 0.59 | 5564 | 4764 | 4924 |
| terse | 0.18 | 0.39 | 0.14 | 0.36 | 0.78 | 5316 | 5272 | 5324 |
| h-m-m | 0.18 | 0.37 | 0.14 | 0.38 | 0.78 | 5380 | 5556 | 4924 |
| raw ms | 0.20 | 0.40 | 0.14 | 0.35 | 0.70 | 5648 | 4552 | 5364 |
