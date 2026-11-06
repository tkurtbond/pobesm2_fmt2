# besm2_fmt -- the Oberon-2 rope-based besm2_fmt (obesm2_fmt2), ported
# from voc to poc, the Peaseblossom Oberon Compiler.  See AGENTS.md and
# PLAN.md.
#
# poc builds a program from its main module's source.  The shared
# modules come compiled, from the poc libraries argparser, ropes and
# polibfyaml (FyThin's C part included) on the library path; the
# program's own modules it finds on the import path (src/, and test/
# for the tests) and compiles again on each build, so there is no import
# order to keep: a new module needs no rule.  What poc writes -- each
# module's .sym, .ll and .o, and the programs -- goes into $(OBJ).
#
# Every program writes this repo's modules' files into the same $(OBJ),
# so make must not build two at once.

SHELL = bash

POC      ?= poc
# Size model: polibfyaml requires -OC, and models can't be mixed, so
# every module here -- ArgParser's, Ropes' and polibfyaml's included --
# gets it.
POCFLAGS := -OC

# libfyaml's link flags: the polibfyaml library doesn't record them.
# (On Linux, -lfyaml.)
FYAML_LIBS := $(shell pkg-config --libs libfyaml)
LINK := $(foreach f,$(FYAML_LIBS),-link $(f))

# The libraries argparser and ropes are installed by the ArgParser and
# Ropes repos (make -f pocGNUmakefile install), and polibfyaml by
# polibfyaml (make install), all in POCLIBDIR.  None of their sources is
# copied here.  Args and Err come from poc's runtime library, poc-rtl.
# POCLIBDIR doesn't follow PREFIX, which says where this program installs.
POCLIBDIR ?= $(HOME)/.local/lib/poc
SHAREDLIBS := argparser ropes polibfyaml
LIBPATH := -library-path $(abspath $(POCLIBDIR))

# The libraries this build takes are the ones in $(POCLIBDIR).  A library
# on POC_LIBRARY_PATH would stop the build if another poc wrote it.
unexport POC_LIBRARY_PATH
IMPORTS := -import-path src $(LIBPATH)

OBJ   := obj
BUILD := build

PROGRAM := pobesm2_fmt2
MAIN    := Besm2Fmt

# Every source and library a program is built from, for make's
# dependencies: a reinstalled library rebuilds the programs.
SHAREDLIBMANIFESTS := $(foreach l,$(SHAREDLIBS),$(wildcard $(POCLIBDIR)/*/OC/$(l).library))
PROGSRC := $(wildcard src/*.Mod)

# Test support modules, and test programs (test/<name>.Mod, main modules).
TESTSUPPORT := test/Check.Mod
TESTS       := TestText TestLayout TestEntities TestOut
TESTBINS    := $(TESTS:%=$(OBJ)/%)

# Only building needs the shared modules, so the cleaning targets don't
# check for them.
ifneq ($(if $(MAKECMDGOALS),$(filter-out clean testclean uninstall golden print-%,$(MAKECMDGOALS)),all),)
$(foreach l,$(SHAREDLIBS),$(if $(wildcard $(POCLIBDIR)/*/OC/$(l).library),,$(error the $(l) library is not in $(POCLIBDIR); $(if $(filter polibfyaml,$(l)),run make install in ~/Repos/Oberon/polibfyaml,run make -f pocGNUmakefile install in ~/Repos/Oberon/$(if $(filter ropes,$(l)),Ropes,ArgParser)))))
endif

.PHONY: all test compare golden valgrind benchmark perfdata perfcompare rst pdf hmm install uninstall clean testclean
.NOTPARALLEL:

all: $(PROGRAM)

$(OBJ):
	mkdir -p $@

$(PROGRAM): src/$(MAIN).Mod $(PROGSRC) $(SHAREDLIBMANIFESTS) | $(OBJ)
	$(POC) $(POCFLAGS) $(IMPORTS) -output-dir $(OBJ) $(LINK) -o $@ $<

$(OBJ)/Test%: test/Test%.Mod $(TESTSUPPORT) $(PROGSRC) $(SHAREDLIBMANIFESTS) | $(OBJ)
	$(POC) $(POCFLAGS) $(IMPORTS) -import-path test -output-dir $(OBJ) $(LINK) -o $@ $<

# Every unit test, run from $(OBJ) (where TestLayout writes its capture
# files), then the command-line checks of test/cli.sh, then the
# golden-output comparison of test/golden.sh, then the upgraded
# fixtures against their originals (test/upgraded.sh); fail at the end
# if any failed.
test: $(PROGRAM) $(TESTBINS)
	@status=0; for t in $(TESTS); do \
	  echo "== $$t"; (cd $(OBJ) && ./$$t) || status=1; \
	done; \
	echo "== cli.sh"; test/cli.sh ./$(PROGRAM) || status=1; \
	echo "== golden.sh"; test/golden.sh check ./$(PROGRAM) || status=1; \
	echo "== upgraded.sh"; test/upgraded.sh ./$(PROGRAM) || status=1; \
	exit $$status

# The program under valgrind (the Buffer port's PLAN.md, step 11;
# obesm2_fmt2's PLAN.md, step 8): every fixture in each format, several
# files, standard input (empty, too), -o, and the early exits.
# polibfyaml's suppressions and still-reachable check, used from its
# checkout: poc-gc.supp for the conservative GC's stack scan
# (uninitialised-value errors in GarbageCollectedHeap.MarkCandidate
# only), libfyaml.supp for libfyaml's realloc(buf, 0) on empty input;
# and test/poc-gc.supp, for the same stack scan's errors in
# DrainMarkStack, which polibfyaml's tests don't reach.
# Each run must have no errors and nothing lost, and every
# still-reachable block must be the collector's own (its heap chunks
# and tables), which vg-reachable.sh checks by allocator (polibfyaml's
# AGENTS.md).
POLIBFYAML ?= $(HOME)/Repos/Oberon/polibfyaml
VALGRIND ?= valgrind -q --error-exitcode=99 --leak-check=full --show-leak-kinds=all \
  --suppressions=$(POLIBFYAML)/test/poc-gc.supp --suppressions=$(POLIBFYAML)/test/libfyaml.supp \
  --suppressions=test/poc-gc.supp
valgrind: $(PROGRAM) | $(OBJ)
	@status=0; n=0; log=$(OBJ)/valgrind.log; \
	vg() { n=$$((n + 1)); $(VALGRIND) ./$(PROGRAM) "$$@" >/dev/null 2>$$log; st=$$?; \
	  if [ $$st -eq 99 ] || grep -qE '(definitely|indirectly|possibly) lost: [1-9]' $$log \
	     || ! $(POLIBFYAML)/test/vg-reachable.sh $$log >/dev/null \
	     || ! grep -q 'are still reachable' $$log; then \
	    echo "FAIL - valgrind $$*"; sed 's/^/    /' $$log; status=1; fi; }; \
	for f in test/data/*.yaml; do \
	  for fl in "" "-s -1" "-t -s -b" "-H -S -s" "-m -s"; do vg $$fl $$f </dev/null; done; \
	done; \
	vg -t test/data/*.yaml </dev/null; \
	vg -s <test/data/composite-multi-doc-2e.yaml; \
	vg </dev/null; \
	vg -H -R Root -o $(OBJ)/valgrind.out test/data/composite-2e.yaml </dev/null; \
	vg -h </dev/null; vg -w 3 </dev/null; vg -o /nonexistent/out test/data/composite-2e.yaml </dev/null; \
	vg -o /dev/full test/data/composite-2e.yaml </dev/null; \
	echo "valgrind: $$n runs"; \
	if [ $$status -eq 0 ]; then echo "All checks passed."; else exit 1; fi

# Standard output, standard error and exit status against the voc build
# of this program, obesm2_fmt2, and the Buffer port's binary, over every
# fixture and flag set (PLAN.md, acceptance criteria); see
# test/compare.sh.  Not part of test: it needs both built.
VOC_BESM2_FMT2 ?= $(HOME)/Repos/RPG/Tools/obesm2_fmt2/obesm2_fmt2
OLD_BESM2_FMT  ?= $(HOME)/Repos/RPG/Tools/obesm2_fmt/obesm2_fmt
compare: $(PROGRAM)
	@status=0; \
	echo "== against the voc build, $(VOC_BESM2_FMT2)"; test/compare.sh ./$(PROGRAM) $(VOC_BESM2_FMT2) || status=1; \
	echo "== against the Buffer port, $(OLD_BESM2_FMT)"; test/compare.sh ./$(PROGRAM) $(OLD_BESM2_FMT) || status=1; \
	exit $$status

# Against the Ada binary and the voc build (PLAN.md, "Port to poc"): a
# Markdown report on standard output (make -s benchmark >report.md);
# see tools/benchmark.sh.
benchmark: $(PROGRAM)
	BESM2_FMT=./$(PROGRAM) ADA_BESM2_FMT=$(ADA_BESM2_FMT) OLD_BESM2_FMT=$(VOC_BESM2_FMT2) tools/benchmark.sh

# Performance data for this program alone: tools/perfdata.sh (the same
# file in obesm2_fmt, obesm2_fmt2 and here) times it on inputs made from
# two fixtures, in the four formats, and writes $(PERF_DATA), which make
# perfcompare reads.  The settings are passed to the script; PERF_CPU=
# (empty) turns pinning off.
PERF_DATA       ?= $(BUILD)/perfdata.tsv
PERF_COPIES     ?= 2000
PERF_RUNS_SMALL ?= 31
PERF_RUNS_BIG   ?= 7
PERF_CPU        ?= 2
perfdata: $(PROGRAM) | $(BUILD)
	BESM2_FMT=./$(PROGRAM) PERF_OUT=$(PERF_DATA) PERF_DIR=$(BUILD)/perf PERF_COPIES='$(PERF_COPIES)' \
	  PERF_RUNS_SMALL='$(PERF_RUNS_SMALL)' PERF_RUNS_BIG='$(PERF_RUNS_BIG)' PERF_CPU='$(PERF_CPU)' \
	  tools/perfdata.sh

# The voc and poc builds compared: make perfdata here and in the voc
# build's checkout, OLD_DIR, with the same settings, then a Markdown
# report in $(PERF_REPORT) from tools/perfcompare.sh.
OLD_DIR     ?= $(HOME)/Repos/RPG/Tools/obesm2_fmt2
PERF_REPORT ?= PERFORMANCE-POC-VS-VOC.md
perfcompare: perfdata
	$(MAKE) -C $(OLD_DIR) perfdata PERF_COPIES='$(PERF_COPIES)' PERF_RUNS_SMALL='$(PERF_RUNS_SMALL)' \
	  PERF_RUNS_BIG='$(PERF_RUNS_BIG)' PERF_CPU='$(PERF_CPU)'
	tools/perfcompare.sh $(OLD_DIR)/$(BUILD)/perfdata.tsv $(PERF_DATA) voc poc >$(PERF_REPORT).tmp
	mv $(PERF_REPORT).tmp $(PERF_REPORT)
	@echo "Wrote $(PERF_REPORT)."

# Rewrite test/golden/ from the reference programs: the Ada besm2_fmt
# and, for the cases where the port follows it instead, besm2-rst.  See
# test/golden.cases.  Needs neither this program nor its build.
ADA_BESM2_FMT    ?= $(HOME)/Repos/RPG/Tools/besm2_fmt/besm2_fmt
SCHEME_BESM2_RST ?= besm2-rst
golden:
	ADA_BESM2_FMT=$(ADA_BESM2_FMT) SCHEME_BESM2_RST=$(SCHEME_BESM2_RST) test/golden.sh generate

# ---- Rendered test output, as in the Ada GNUmakefile ----
#
# reST from each -2e fixture, with subtotals (-s): grid tables (the
# default), terse (-t) and tbl tables in a raw ms block (-m), each also
# with -n; then a letter-sized PDF of each through pandoc's ms writer
# and the tkb template.  The Ada GNUmakefile calls its -n variants
# "-unicode-minus", from besm2-rst, where -n turns the Unicode minus
# on; in the Ada version and here -n turns it off, so they are
# "-ascii-minus" here (ADA-DIFFERENCES.md, 1.11).  h-m-m output
# isn't reST, so pandoc can't render it; make hmm, below, builds it.
# Each variant is also built without -s, with "-nosubtotals" appended,
# so the output with and without the subtotals (and the skill points
# total) can be compared side by side.
RST_DATA := $(wildcard test/data/*-2e.yaml)
RST_BASES := $(basename $(notdir $(RST_DATA)))
RST_VARIANTS := % %-terse %-tbl %-ascii-minus %-tbl-ascii-minus \
	%-nosubtotals %-terse-nosubtotals %-tbl-nosubtotals \
	%-ascii-minus-nosubtotals %-tbl-ascii-minus-nosubtotals
RST_OUTPUT := $(foreach v,$(RST_VARIANTS),$(patsubst %,$(BUILD)/$(v).gen.rst,$(RST_BASES)))
PDF_OUTPUT := $(RST_OUTPUT:.gen.rst=.ms.pdf)

rst: $(RST_OUTPUT)
pdf: $(PDF_OUTPUT)

$(BUILD):
	mkdir -p $@

$(BUILD)/%.gen.rst: test/data/%.yaml $(PROGRAM) | $(BUILD)
	./$(PROGRAM) -s $< >$@
$(BUILD)/%-terse.gen.rst: test/data/%.yaml $(PROGRAM) | $(BUILD)
	./$(PROGRAM) -s -t $< >$@
$(BUILD)/%-tbl.gen.rst: test/data/%.yaml $(PROGRAM) | $(BUILD)
	./$(PROGRAM) -s -m $< >$@
$(BUILD)/%-ascii-minus.gen.rst: test/data/%.yaml $(PROGRAM) | $(BUILD)
	./$(PROGRAM) -s -n $< >$@
$(BUILD)/%-tbl-ascii-minus.gen.rst: test/data/%.yaml $(PROGRAM) | $(BUILD)
	./$(PROGRAM) -s -m -n $< >$@
$(BUILD)/%-nosubtotals.gen.rst: test/data/%.yaml $(PROGRAM) | $(BUILD)
	./$(PROGRAM) $< >$@
$(BUILD)/%-terse-nosubtotals.gen.rst: test/data/%.yaml $(PROGRAM) | $(BUILD)
	./$(PROGRAM) -t $< >$@
$(BUILD)/%-tbl-nosubtotals.gen.rst: test/data/%.yaml $(PROGRAM) | $(BUILD)
	./$(PROGRAM) -m $< >$@
$(BUILD)/%-ascii-minus-nosubtotals.gen.rst: test/data/%.yaml $(PROGRAM) | $(BUILD)
	./$(PROGRAM) -n $< >$@
$(BUILD)/%-tbl-ascii-minus-nosubtotals.gen.rst: test/data/%.yaml $(PROGRAM) | $(BUILD)
	./$(PROGRAM) -m -n $< >$@

#MS_COLUMNS = -V twocolumns
$(BUILD)/%.ms.pdf: $(BUILD)/%.gen.rst
	pandoc -r rst -w ms --template=tkb $(MS_COLUMNS) -o $@ $<

.PRECIOUS: $(BUILD)/%.gen.rst

# h-m-m outlines from the same fixtures, with subtotals (-s), as make
# rst's: items in their entity's node (-H), and as separate nodes (-S).
# No PDF (it isn't reST), and no -n variant: defect points are written
# "N BP", so -n changes only enhancement and limiter signs (of the
# fixtures, only synthetic-2e's), as in terse, which has none either.
HMM_VARIANTS := % %-separate
HMM_OUTPUT := $(foreach v,$(HMM_VARIANTS),$(patsubst %,$(BUILD)/$(v).gen.hmm,$(RST_BASES)))

hmm: $(HMM_OUTPUT)

$(BUILD)/%.gen.hmm: test/data/%.yaml $(PROGRAM) | $(BUILD)
	./$(PROGRAM) -s -H $< >$@
$(BUILD)/%-separate.gen.hmm: test/data/%.yaml $(PROGRAM) | $(BUILD)
	./$(PROGRAM) -s -H -S $< >$@

# ---- Installation ----
#
# To $(PREFIX)/bin, $HOME/local/bin by default as in the Ada version
# (its besm2_fmt.gpr's Install package), under its own name, beside the
# Ada besm2_fmt and the voc builds.  DESTDIR is prepended, for staging.
PREFIX ?= $(HOME)/local
BINDIR ?= $(PREFIX)/bin

install: $(PROGRAM)
	install -d $(DESTDIR)$(BINDIR)
	install -m 755 $(PROGRAM) $(DESTDIR)$(BINDIR)/$(PROGRAM)

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/$(PROGRAM)

clean: testclean
	rm -rf $(OBJ) $(PROGRAM)

testclean:
	rm -rf $(BUILD)

print-%: ; @echo $* = $($*)
