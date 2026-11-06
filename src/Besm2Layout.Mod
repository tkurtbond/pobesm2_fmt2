MODULE Besm2Layout; (* Padding, word wrapping, grid-table rows, emphasis *)

(* The Ada BESM2_Fmt.Text_Layout: fixed-width padding, greedy word
   wrap, and the bordered "|...|...|" rows of a reST grid table, which
   besm2-rst.scm builds from SRFI 166's padded, wrapped and columnar.
   The Scheme only ever uses a narrow slice of those -- plain,
   fixed-width, single-font text, with bold and italics as literal "**"
   and "*" in the string -- so this is a small purpose-built module, not
   a general formatting library.

   Rows and separators are written to Besm2Out.  Besm2Config supplies
   the table width and the flags the emphasis procedures and MinusGlyph
   follow. *)

IMPORT Besm2Config, Besm2Out, Besm2Text, Ropes;

CONST
  LeftAlign* = 0; RightAlign* = 1;

  (* besm2-rst.scm's *num-width*: the widest of "LEVEL", "VALUE" and
     "POINTS" (6), plus the 4 its main always adds for the "**" around
     a bold header cell -- even under -B/--no-bold-head, when the
     header just gets some slack.  Ported as is. *)
  NumWidth* = 10;

TYPE
  Rope* = Ropes.Rope;

VAR
  unicodeMinus, asciiMinus, unicodeTimes, asciiTimes, overrideMark, stars, star, blank: Rope;
  breaks: Ropes.CharSet;   (* where WordWrap may break a line *)

(* r padded with blanks to width characters (DisplayLength, not bytes),
   on the right for LeftAlign, on the left for RightAlign.  r is
   returned unchanged if it is already that wide or wider: like SRFI
   166's padded, this never truncates (so not Ropes.Head, which does,
   and counts bytes). *)
PROCEDURE Pad*(r: Rope; width: LONGINT; align: INTEGER): Rope;
  VAR fill: Rope;
BEGIN
  (* NIL, and so no change, if r is already wide enough. *)
  fill := Ropes.Make(width - Besm2Text.DisplayLength(r), " ");
  IF align = RightAlign THEN RETURN Ropes.Cat(fill, r) END;
  RETURN Ropes.Cat(r, fill)
END Pad;

(* Sets lines to r wrapped greedily to width characters: words
   separated by runs of whitespace, joined by one blank.  A word longer
   than width is not broken; it gets a line of its own and overruns.
   An empty r gives one empty line, not none, since a table row needs
   a line even when its wrapped column is "".

   Every whitespace character separates words, newlines included: a
   YAML literal block scalar ("details: |") carries its own line breaks
   into the text, and the real besm2-rst.scm output re-fills them as
   ordinary text (FV2021-Coleopteran-2e.yaml's "Weapon: Rocket Pod"
   attribute).  Printing the newline instead would break the row's
   "|...|" borders -- a bug the Ada port found and fixed. *)
PROCEDURE WordWrap*(r: Rope; width: LONGINT; VAR lines: Besm2Text.List);
  VAR cur, word: Rope; from, start, len, curLen, wordLen: LONGINT;
BEGIN
  Besm2Text.Clear(lines);
  cur := NIL; curLen := 0; from := 0;
  LOOP
    (* The next run of characters that aren't breaks; none left if its
       length is 0.  Leading and trailing whitespace are skipped with
       the rest. *)
    Ropes.FindToken(r, breaks, FALSE, from, start, len);
    IF len = 0 THEN EXIT END;
    word := Ropes.Substring(r, start, len); wordLen := Besm2Text.DisplayLength(word);
    IF cur = NIL THEN
      cur := word; curLen := wordLen
    ELSIF curLen + 1 + wordLen <= width THEN
      cur := Ropes.Cat(Ropes.Cat(cur, blank), word);
      INC(curLen, 1 + wordLen)
    ELSE
      Besm2Text.Append(lines, cur);
      cur := word; curLen := wordLen
    END;
    from := start + len
  END;
  Besm2Text.Append(lines, cur)
END WordWrap;

(* The width of the last, wrapped, column of a row of numColumns
   columns: whatever the fixed-width columns and the borders leave of
   the table width: table width - 2 - (columns - 1) * (NumWidth + 1),
   as besm2-rst.scm's separator-line computes it. *)
PROCEDURE WrapWidth(numColumns: INTEGER): LONGINT;
BEGIN RETURN Besm2Config.tableWidth - 2 - (numColumns - 1) * (NumWidth + 1)
END WrapWidth;

(* Writes one row of a grid table: one or more "|...|...|" lines.  All
   columns but the last are NumWidth characters wide; the last is
   wrapped to the rest of the table width, and on its continuation
   lines the other columns are blank.  besm2-rst.scm's row2 and row3,
   for cols.n = 2 and 3.  Callers apply Hbolding and friends to the
   column text first, as the Scheme callers do. *)
PROCEDURE PutRow*(VAR cols: Besm2Text.List);
  VAR lines: Besm2Text.List; wrap: LONGINT; l, c: INTEGER;
BEGIN
  wrap := WrapWidth(cols.n);
  WordWrap(cols.items[cols.n - 1], wrap, lines);
  FOR l := 0 TO lines.n - 1 DO
    Besm2Out.Char("|");
    FOR c := 0 TO cols.n - 2 DO
      IF l = 0 THEN Besm2Out.Rope(Pad(cols.items[c], NumWidth, LeftAlign))
      ELSE Besm2Out.Repeat(" ", NumWidth)
      END;
      Besm2Out.Char("|")
    END;
    Besm2Out.Rope(Pad(lines.items[l], wrap, LeftAlign));
    Besm2Out.Char("|"); Besm2Out.Ln
  END
END PutRow;

(* A row of two or three columns; NIL is an empty column. *)
PROCEDURE Row2*(a, b: Rope);
  VAR cols: Besm2Text.List;
BEGIN
  Besm2Text.Clear(cols);
  Besm2Text.Append(cols, a); Besm2Text.Append(cols, b);
  PutRow(cols)
END Row2;

PROCEDURE Row3*(a, b, c: Rope);
  VAR cols: Besm2Text.List;
BEGIN
  Besm2Text.Clear(cols);
  Besm2Text.Append(cols, a); Besm2Text.Append(cols, b); Besm2Text.Append(cols, c);
  PutRow(cols)
END Row3;

(* Writes one "+---+---+...+" line: numColumns - 1 segments of NumWidth
   fill characters, then one taking the rest of the table width.
   besm2-rst.scm's separator-line: sep1/sep2/sep3 with fill "-", and
   headsep2/headsep3 with Besm2Config.headSep. *)
PROCEDURE SeparatorLine*(numColumns: INTEGER; fill: CHAR);
  VAR c: INTEGER;
BEGIN
  Besm2Out.Char("+");
  FOR c := 1 TO numColumns - 1 DO
    Besm2Out.Repeat(fill, NumWidth); Besm2Out.Char("+")
  END;
  Besm2Out.Repeat(fill, WrapWidth(numColumns));
  Besm2Out.Char("+"); Besm2Out.Ln
END SeparatorLine;

(* Writes one "| ... |" line spanning the table: besm2-rst.scm's empty,
   used between sections under -1/--one.  The Ada port wrote this from
   the Scheme's definition, with no fixture to check it; this port's -1
   output matches both the Ada binary and besm2-rst (the Buffer port's
   PLAN.md, step 6). *)
PROCEDURE EmptyRow*;
BEGIN
  Besm2Out.Char("|");
  Besm2Out.Repeat(" ", Besm2Config.tableWidth - 2);
  Besm2Out.Char("|"); Besm2Out.Ln
END EmptyRow;

(* ---- Emphasis ---- *)

(* Always "**...**" and "*...*": besm2-rst.scm's bold and italics.  An
   empty r gives "****" and "**", as there. *)
PROCEDURE Bold*(r: Rope): Rope;
BEGIN RETURN Ropes.Cat(Ropes.Cat(stars, r), stars)
END Bold;

PROCEDURE Italics*(r: Rope): Rope;
BEGIN RETURN Ropes.Cat(Ropes.Cat(star, r), star)
END Italics;

(* Bold under -b/--bold: besm2-rst.scm's bolding. *)
PROCEDURE Bolding*(r: Rope): Rope;
BEGIN
  IF Besm2Config.bolding THEN RETURN Bold(r) END;
  RETURN r
END Bolding;

(* Italic under -i/--italics: besm2-rst.scm's italicizing. *)
PROCEDURE Italicizing*(r: Rope): Rope;
BEGIN
  IF Besm2Config.italicizing THEN RETURN Italics(r) END;
  RETURN r
END Italicizing;

(* Bold under -b, else italic under -i: besm2-rst.scm's emphasizing,
   for the names of attributes, defects and skills. *)
PROCEDURE Emphasizing*(r: Rope): Rope;
BEGIN
  IF Besm2Config.bolding THEN RETURN Bold(r)
  ELSIF Besm2Config.italicizing THEN RETURN Italics(r)
  END;
  RETURN r
END Emphasizing;

(* Bold unless -B/--no-bold-head: besm2-rst.scm's hbolding, for grid
   table header cells. *)
PROCEDURE Hbolding*(r: Rope): Rope;
BEGIN
  IF Besm2Config.boldHead THEN RETURN Bold(r) END;
  RETURN r
END Hbolding;

(* The sign for a negative number this program writes itself: U+2212
   MINUS SIGN, or "-" under -n/--no-unicode-minus.  besm2-rst.scm's
   minus-glyph, with the Ada version's default.  Used for the
   enhancement signs in attribute details (all formats) and the defect
   points and totals of the grid and raw ms formats.  Terse and h-m-m
   write defect points as "N BP", with no sign. *)
PROCEDURE MinusGlyph*(): Rope;
BEGIN
  IF Besm2Config.unicodeMinus THEN RETURN unicodeMinus END;
  RETURN asciiMinus
END MinusGlyph;

(* MULTIPLICATION SIGN (U+00D7), or "x" under -n/--no-unicode-minus:
   the "×2" of a Weapon Attack Ability or Disability taken twice
   (besm2_cg_po's PLAN.md, A4; the book writes "x 2", p. 92).  The
   Ada Times_Glyph. *)
PROCEDURE TimesGlyph*(): Rope;
BEGIN
  IF Besm2Config.unicodeMinus THEN RETURN unicodeTimes END;
  RETURN asciiTimes
END TimesGlyph;

(* What follows an overridden number (`overrides:`, besm2_cg_po's
   PLAN.md, A4) in the terse and grid formats: "*", escaped so that
   reST doesn't read it as the start of emphasis.  The Ada
   Override_Mark. *)
PROCEDURE OverrideMark*(): Rope;
BEGIN RETURN overrideMark
END OverrideMark;

(* The entity's notes, if any, as a reStructuredText bullet list after a
   bold "Notes:" paragraph, one note per item, the lines after a note's
   first indented two blanks so it stays one item: the terse, grid and
   raw ms formats all end an entity with this. *)
PROCEDURE Notes*(l: Besm2Text.List);
  VAR i: INTEGER; s: Rope; from, nl: LONGINT;
BEGIN
  IF l.n > 0 THEN
    Besm2Out.Rope(Bold(Ropes.FromString("Notes:"))); Besm2Out.Ln; Besm2Out.Ln;
    FOR i := 0 TO l.n - 1 DO
      s := l.items[i]; Besm2Out.String("- "); from := 0;
      nl := Ropes.IndexChar(s, 0AX, from);
      WHILE nl >= 0 DO
        Besm2Out.Rope(Ropes.Substring(s, from, nl + 1 - from)); Besm2Out.String("  ");
        from := nl + 1; nl := Ropes.IndexChar(s, 0AX, from)
      END;
      Besm2Out.Rope(Ropes.Substring(s, from, Ropes.Length(s) - from));
      Besm2Out.Ln
    END;
    Besm2Out.Ln
  END
END Notes;

BEGIN
  unicodeMinus := Ropes.FromString("−");   (* U+2212, UTF-8 E2 88 92 *)
  asciiMinus := Ropes.FromString("-");
  unicodeTimes := Ropes.FromString("×");   (* U+00D7, UTF-8 C3 97 *)
  asciiTimes := Ropes.FromString("x");
  overrideMark := Ropes.FromString("\*");
  stars := Ropes.FromString("**"); star := Ropes.FromString("*");
  blank := Ropes.FromString(" ");
  Ropes.MakeCharSet(" ", breaks);
  breaks.has[09H] := TRUE; breaks.has[0AH] := TRUE; breaks.has[0DH] := TRUE
END Besm2Layout.
