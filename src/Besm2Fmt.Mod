MODULE Besm2Fmt; (* besm2_fmt: BESM 2E YAML to reStructuredText *)

(* Oberon-2 port of the Ada besm2_fmt (besm2_fmt_main.adb), itself a
   port of besm2-rst.scm, with every string a Ropes.Rope.  See PLAN.md,
   and the Buffer port's PLAN.md, section 7. *)

IMPORT Besm2Cli, Besm2Config, Besm2Entities, Besm2Grid, Besm2Hmm, Besm2Out, Besm2RawMs, Besm2Terse, Besm2Text,
  Err, Fyaml, FyamlStreams, Out, Platform, Ropes, SYSTEM;

VAR
  errorsReported: BOOLEAN;   (* an input error was reported: exit 1 *)

(* strerror, for an -o/--output file that can't be created: C's
   char *strerror(int), its int being SYSTEM.INT32 whatever the size
   model. *)
PROCEDURE ["C", "strerror"] strerror(e: SYSTEM.INT32): SYSTEM.ADDRESS;

(* Writes r to standard error. *)
PROCEDURE ErrRope(r: Ropes.Rope);
  VAR s: Besm2Text.String;
BEGIN s := Besm2Text.Chars(r); Err.String(s^)
END ErrRope;

(* Writes the OS's text for error code e, from strerror, to standard
   error. *)
PROCEDURE ErrReason(e: Platform.ErrorCode);
  VAR p: SYSTEM.ADDRESS; c: CHAR;
BEGIN
  p := strerror(SYSTEM.VAL(SYSTEM.INT32, e));
  IF p # 0 THEN
    SYSTEM.GET(p, c);
    WHILE c # 0X DO Err.Char(c); INC(p); SYSTEM.GET(p, c) END
  END
END ErrReason;

(* Reports an error this program found in processing source, in the
   Ada version's words: "besm2_fmt: error processing SOURCE: MESSAGE".
   Output so far is flushed first, so it comes before the error when
   both go to the terminal. *)
PROCEDURE Report(source, msg: Ropes.Rope);
BEGIN
  errorsReported := TRUE;
  Besm2Out.Flush;
  Err.String("besm2_fmt: error processing "); ErrRope(source); Err.String(": ");
  ErrRope(msg); Err.Ln
END Report;

(* Reports an error from polibfyaml.  Its message already names the file,
   gcc style ("FILE:LINE:COLUMN: error: TEXT", one line per error, each
   ending in a newline), so it gets only the program's name in front:
   a deliberate difference from the Ada wording (the Buffer port's
   PLAN.md, section 5). *)
PROCEDURE ReportYaml(err: Fyaml.Error);
BEGIN
  errorsReported := TRUE;
  Besm2Out.Flush;
  Err.String("besm2_fmt: "); Err.String(err.msg^)
END ReportYaml;

(* The entities of one document.  count runs on across the documents of
   a file: 1 for the file's first entity, whichever document it is in.
   Each entity is loaded completely before any of it is written, so one
   that fails writes nothing: it is reported, isn't counted, and the
   next entity is processed.  A top level that isn't a sequence ends
   the document, as in the Ada version. *)
PROCEDURE ProcessDocument(d: Fyaml.Document; source: Ropes.Rope; VAR count: INTEGER);
  VAR root, item: Fyaml.Node; it: Fyaml.ItemIter; e: Besm2Entities.Entity;
    yerr: Fyaml.Error; msg: Ropes.Rope;
BEGIN
  root := d.Root();
  IF (root = NIL) OR ~root.IsSequence() THEN
    msg := Ropes.Cat(Ropes.FromString("expected a top-level YAML sequence of entities in "), source);
    Report(source, msg);
    RETURN
  END;
  root.Items(it);
  WHILE it.Next(item) DO
    IF ~Besm2Entities.Load(item, e, yerr, msg) THEN
      IF yerr # NIL THEN ReportYaml(yerr) ELSE Report(source, msg) END
    ELSE
      INC(count);
      CASE Besm2Config.format OF
        Besm2Config.Terse: Besm2Terse.ProcessEntity(e, count)
      | Besm2Config.Grid: Besm2Grid.ProcessEntity(e, count)
      | Besm2Config.Hmm: Besm2Hmm.ProcessEntity(e, count)
      | Besm2Config.RawMs: Besm2RawMs.ProcessEntity(e, count)
      ELSE HALT(20)   (* Besm2Cli sets no other format *)
      END
    END
  END
END ProcessDocument;

(* One file, or standard input if stdin.  An error in an entity is
   reported by ProcessDocument; a YAML error ends the file, since
   libfyaml can't resume after one.  Either way the run goes on with
   the next file. *)
PROCEDURE ProcessOne(name: Ropes.Rope; stdin: BOOLEAN);
  VAR s: FyamlStreams.Stream; d: Fyaml.Document; err: Fyaml.Error;
    source: Ropes.Rope; path: Besm2Text.String; count: INTEGER;
BEGIN
  IF stdin THEN source := Ropes.FromString(Fyaml.stdinName); s := FyamlStreams.OpenStdin(err)
  ELSE source := name; path := Besm2Text.Chars(name); s := FyamlStreams.OpenFile(path^, err)
  END;
  IF s = NIL THEN ReportYaml(err); RETURN END;
  count := 0;
  d := s.Next(err);
  WHILE d # NIL DO
    ProcessDocument(d, source, count);
    d.Close;
    d := s.Next(err)
  END;
  IF err # NIL THEN ReportYaml(err) END;
  s.Close
END ProcessOne;

PROCEDURE ProcessAll;
  VAR i: INTEGER;
BEGIN
  IF Besm2Cli.files.n = 0 THEN
    ProcessOne(NIL, TRUE)
  ELSE
    FOR i := 0 TO Besm2Cli.files.n - 1 DO ProcessOne(Besm2Cli.files.items[i], FALSE) END
  END
END ProcessAll;

PROCEDURE Main;
  VAR e: Platform.ErrorCode; path: Besm2Text.String;
BEGIN
  Besm2Cli.Parse;   (* exits with status 2 on a command-line mistake *)
  IF Besm2Cli.helpShown THEN
    (* Asking for help isn't an error. *)
    Out.Flush; Platform.Exit(0)
  END;

  IF Besm2Config.hasOutputFile THEN
    path := Besm2Text.Chars(Besm2Config.outputFile);
    e := Besm2Out.ToFile(path^);
    IF e # 0 THEN
      (* The Ada version died here with an unhandled Name_Error, status
         1, until it was fixed to report this, as the port did (the
         Buffer port's ADA-DIFFERENCES.md, 1.5). *)
      Err.String("besm2_fmt: can't create "); Err.String(path^);
      Err.String(": "); ErrReason(e); Err.Ln;
      Platform.Exit(1)
    END
  END;

  (* The -R/--hmm-root line: once per run, not per entity, and with the
     rest of the output, into the -o/--output file if any. *)
  IF Besm2Config.hmmOutput & Besm2Config.hasHmmRoot THEN
    Besm2Out.Repeat(09X, Besm2Config.hmmDepth);
    Besm2Out.Rope(Besm2Config.hmmRoot); Besm2Out.Ln
  END;

  errorsReported := FALSE;
  ProcessAll;

  e := Besm2Out.Close();
  IF e # 0 THEN
    Err.String("besm2_fmt: error writing output: "); ErrReason(e); Err.Ln;
    Platform.Exit(1)
  END;
  IF errorsReported THEN Platform.Exit(1) END
END Main;

BEGIN
  Main
END Besm2Fmt.
