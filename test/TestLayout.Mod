MODULE TestLayout; (* Besm2Layout, without YAML *)

(* A port of the Ada test/test_text_layout.adb (the Buffer port's
   PLAN.md, section 8),
   check for check and in the same order, plus a few for the Oberon
   port's own Row2 and EmptyRow.  PutRow and SeparatorLine are checked
   against the real grid-table fragment of enyon-boase-2e's output,
   captured by sending Besm2Out to a file and reading it back.  Run
   from obj/, where the capture files go.

   Each capture has its own file.  Under voc it had to: voc's Files.Old
   returns the File it cached the first time it saw a file (by inode),
   with its old buffers, so a capture rewritten in place (O_TRUNC) read
   back as the first one.  poc's Files reads a rewritten file afresh
   (confirmed), but the separate files are kept. *)

IMPORT Besm2Config, Besm2Layout, Besm2Out, Besm2Text, Check, Files, Ropes;

CONST
  Left = Besm2Layout.LeftAlign; Right = Besm2Layout.RightAlign;

TYPE
  Rope = Ropes.Rope;

VAR
  lines: ARRAY 16 OF Rope;
  nlines: INTEGER;
  rocket, expected: ARRAY 256 OF CHAR;
  r: Rope;

PROCEDURE Is(r: Rope; t: ARRAY OF CHAR): BOOLEAN;
BEGIN RETURN Ropes.EqualString(r, t)
END Is;

PROCEDURE R(s: ARRAY OF CHAR): Rope;
BEGIN RETURN Ropes.FromString(s)
END R;

(* s, then n blanks, then the closing "|" of a table row. *)
PROCEDURE Bordered(s: ARRAY OF CHAR; n: INTEGER): Rope;
BEGIN RETURN Ropes.AppendChar(Ropes.Cat(R(s), Ropes.Make(n, " ")), "|")
END Bordered;

(* The lines of text joined with sep, as the Ada test's Joined. *)
PROCEDURE WrappedRope(text: Rope; width: LONGINT; sep: ARRAY OF CHAR): Rope;
  VAR l: Besm2Text.List;
BEGIN
  Besm2Layout.WordWrap(text, width, l);
  RETURN Besm2Text.Join(l, sep)
END WrappedRope;

PROCEDURE Wrapped(text: ARRAY OF CHAR; width: LONGINT; sep: ARRAY OF CHAR): Rope;
BEGIN RETURN WrappedRope(R(text), width, sep)
END Wrapped;

(* The number of lines text wraps to. *)
PROCEDURE WrapCount(text: ARRAY OF CHAR; width: LONGINT): INTEGER;
  VAR l: Besm2Text.List;
BEGIN
  Besm2Layout.WordWrap(R(text), width, l);
  RETURN l.n
END WrapCount;

(* Reads the capture file into lines[0 .. nlines-1], without their line
   feeds. *)
PROCEDURE ReadCapture(name: ARRAY OF CHAR);
  VAR f: Files.File; rd: Files.Rider; line: Rope;
BEGIN
  nlines := 0;
  f := Files.Old(name);
  IF f = NIL THEN RETURN END;
  Files.Set(rd, f, 0);
  WHILE Ropes.ReadLineRider(rd, line) DO
    IF nlines < LEN(lines) THEN lines[nlines] := line; INC(nlines) END
  END;
  Files.Close(f)
END ReadCapture;

(* Output written between StartCapture(name) and EndCapture(name)
   goes to the file name and then into lines. *)
PROCEDURE StartCapture(name: ARRAY OF CHAR);
BEGIN
  Check.Check(Besm2Out.ToFile(name) = 0, "Besm2Out.ToFile creates the capture file")
END StartCapture;

PROCEDURE EndCapture(name: ARRAY OF CHAR);
BEGIN
  Check.Check(Besm2Out.Close() = 0, "Besm2Out.Close writes and closes it");
  ReadCapture(name)
END EndCapture;

(* Line i of the capture; a rope that matches nothing if there is no
   such line (NIL would match an empty expected line). *)
PROCEDURE Line(i: INTEGER): Rope;
BEGIN
  IF i < nlines THEN RETURN lines[i] END;
  RETURN R("<no such line>")
END Line;

BEGIN
  (* ---- DisplayLength ---- *)
  Check.Check(Besm2Text.DisplayLength(R("Body")) = 4, "DisplayLength of plain ASCII");
  Check.Check(Besm2Text.DisplayLength(R("“")) = 1, "DisplayLength of a 3-byte UTF-8 char (curly quote)");
  Check.Check(Besm2Text.DisplayLength(R("Shots ×2")) = 8,
    "DisplayLength of a 2-byte UTF-8 char (multiplication sign) in context");

  (* ---- Pad ---- *)
  Check.Check(Is(Besm2Layout.Pad(R("8"), 10, Left), "8         "), "Pad left-aligns and fills with spaces");
  Check.Check(Is(Besm2Layout.Pad(R("8"), 10, Right), "         8"), "Pad right-aligns on request");
  Check.Check(Is(Besm2Layout.Pad(R("POINTS"), 6, Left), "POINTS"),
    "Pad passes through unchanged text already at Width");
  Check.Check(Is(Besm2Layout.Pad(R("ATTRIBUTES TOTAL"), 6, Left), "ATTRIBUTES TOTAL"),
    "Pad never truncates text already over Width");
  Check.Check(Is(Besm2Layout.Pad(R("“ok"), 4, Left), "“ok "),
    "Pad counts UTF-8 codepoints, not bytes, toward Width");

  (* ---- WordWrap ---- *)
  Check.Check(Is(Wrapped("", 10, "|"), "") & (WrapCount("", 10) = 1),
    "WordWrap of an empty string yields one empty line");
  Check.Check(WrapCount("   ", 10) = 1, "WordWrap of only whitespace yields one empty line too");
  Check.Check(Is(Wrapped("Body", 36, "|"), "Body"), "WordWrap of short text yields one line unchanged");
  rocket := "Weapon: Rocket Pod (Damage 45, Auto-fire, Area Effect, Limited Shots ×2 [3 shots], Stoppable)";
  expected := "Weapon: Rocket Pod (Damage 45,|Auto-fire, Area Effect, Limited|Shots ×2 [3 shots], Stoppable)";
  Check.Check(Is(Wrapped(rocket, 36, "|"), expected),
    'WordWrap greedily fills lines on space boundaries -- matches the golden "Weapon: Rocket Pod" attribute wrap at width 36');
  (* Three leaves: the text, the line feed, and the rest. *)
  r := Ropes.Cat(Ropes.AppendChar(R("Weapon: Rocket Pod (Damage 45, Auto-fire, Area Effect, Limited Shots ×2 [3 shots],"),
                                  0AX), R("Stoppable)"));
  Check.Check(Is(WrappedRope(r, 36, "|"), expected),
    'WordWrap treats an embedded newline (from a "details: |" YAML block scalar) as a word break, not literal content');
  Check.Check(Is(Wrapped("Supercalifragilisticexpialidocious", 5, "|"), "Supercalifragilisticexpialidocious"),
    "WordWrap never breaks a single word longer than Width");
  Check.Check(Is(Wrapped("  a   b  ", 10, "|"), "a b"),
    "WordWrap collapses runs of whitespace and drops leading and trailing ones");
  (* A word that straddles two leaves is still one word. *)
  r := Ropes.Cat(R("a first leaf that ends mid-wo"), R("rd and a second leaf that goes on"));
  Check.Check((Ropes.Depth(r) = 1)
    & Is(WrappedRope(r, 20, "|"), "a first leaf that|ends mid-word and a|second leaf that|goes on"),
    "WordWrap keeps a word that crosses a leaf boundary whole");

  (* ---- Bold / Italics / Bolding / Italicizing / Emphasizing / Hbolding ---- *)
  Check.Check(Is(Besm2Layout.Bold(R("STAT")), "**STAT**"), "Bold always wraps in **");
  Check.Check(Is(Besm2Layout.Bold(NIL), "****") & Is(Besm2Layout.Italics(NIL), "**"),
    "Bold and Italics of the empty rope are the markers alone");
  Check.Check(Is(Besm2Layout.Italics(R("tagline")), "*tagline*"), "Italics always wraps in *");

  Check.Check(~Besm2Config.bolding & Is(Besm2Layout.Bolding(R("x")), "x"),
    "Bolding off by default leaves text unchanged");
  Besm2Config.bolding := TRUE;
  Check.Check(Is(Besm2Layout.Bolding(R("x")), "**x**"), "Bolding wraps in ** once -b/--bold is set");
  Check.Check(Is(Besm2Layout.Emphasizing(R("x")), "**x**"), "Emphasizing prefers Bolding over Italicizing");
  Besm2Config.bolding := FALSE;

  Check.Check(~Besm2Config.italicizing & Is(Besm2Layout.Italicizing(R("x")), "x"),
    "Italicizing off by default leaves text unchanged");
  Besm2Config.italicizing := TRUE;
  Check.Check(Is(Besm2Layout.Italicizing(R("x")), "*x*"), "Italicizing wraps in * once -i/--italics is set");
  Check.Check(Is(Besm2Layout.Emphasizing(R("x")), "*x*"), "Emphasizing falls back to Italicizing when Bolding is off");
  Besm2Config.italicizing := FALSE;
  Check.Check(Is(Besm2Layout.Emphasizing(R("x")), "x"), "Emphasizing leaves text unchanged when neither flag is set");

  Check.Check(Besm2Config.boldHead & Is(Besm2Layout.Hbolding(R("VALUE")), "**VALUE**"),
    "Hbolding is on by default (-B/--no-bold-head not given)");
  Besm2Config.boldHead := FALSE;
  Check.Check(Is(Besm2Layout.Hbolding(R("VALUE")), "VALUE"),
    "Hbolding leaves text unchanged once -B/--no-bold-head is set");
  Besm2Config.boldHead := TRUE;

  (* ---- MinusGlyph: U+2212 (E2 88 92) by default, "-" under -n ---- *)
  r := Ropes.AppendChar(Ropes.AppendChar(Ropes.FromChar(0E2X), 88X), 92X);
  Check.Check(Besm2Config.unicodeMinus & Ropes.Equal(Besm2Layout.MinusGlyph(), r),
    "MinusGlyph is Unicode MINUS SIGN (U+2212) by default (-n not given)");
  Besm2Config.unicodeMinus := FALSE;
  Check.Check(Is(Besm2Layout.MinusGlyph(), "-"), "MinusGlyph is ASCII hyphen-minus once -n/--no-unicode-minus is set");
  Besm2Config.unicodeMinus := TRUE;

  (* ---- PutRow / SeparatorLine, against the golden STAT table of
     enyon-boase-2e (table width 60, NumWidth 10) ---- *)
  StartCapture("TestLayout-stat.capture");
  Besm2Layout.SeparatorLine(3, "-");
  Besm2Layout.SeparatorLine(3, "=");
  Besm2Layout.Row3(Besm2Layout.Hbolding(R("VALUE")), Besm2Layout.Hbolding(R("POINTS")),
                   Besm2Layout.Hbolding(R("STAT")));
  Besm2Layout.Row3(R("8"), R("8"), R("Body"));
  EndCapture("TestLayout-stat.capture");
  Check.Check(Is(Line(0), "+----------+----------+------------------------------------+"),
    "SeparatorLine(3) matches the golden STAT table's '-' border");
  Check.Check(Is(Line(1), "+==========+==========+====================================+"),
    "SeparatorLine(3, '=') matches the golden STAT table's header border");
  Check.Check(Is(Line(2), "|**VALUE** |**POINTS**|**STAT**                            |"),
    "PutRow of the hbolded header matches the golden STAT header row");
  Check.Check(Is(Line(3), "|8         |8         |Body                                |"),
    "PutRow of a data row matches the golden STAT data row");
  Check.Check(nlines = 4, "nothing else was written");

  (* ---- Not in the Ada test: a wrapped two-column row, and EmptyRow ---- *)
  StartCapture("TestLayout-row2.capture");
  Besm2Layout.Row2(R("9"), R("Attack Combat Value, and some more words to wrap it over two lines"));
  Besm2Layout.EmptyRow;
  Besm2Layout.Row3(NIL, R("5"), NIL);
  EndCapture("TestLayout-row2.capture");
  Check.Check(Ropes.Equal(Line(0), Bordered("|9         |Attack Combat Value, and some more words to", 47 - 43)),
    "Row2 wraps its last column to the rest of the width (47)");
  Check.Check(Ropes.Equal(Line(1), Bordered("|          |wrap it over two lines", 47 - 22)),
    "Row2's continuation line is blank in the other column");
  Check.Check(Ropes.Equal(Line(2), Bordered("|", 58)),
    "EmptyRow spans the table width");
  Check.Check(Is(Line(3), "|          |5         |                                    |"),
    "a NIL column is an empty cell");
  Check.Check(nlines = 4, "nothing else was written");

  Check.Summary
END TestLayout.
