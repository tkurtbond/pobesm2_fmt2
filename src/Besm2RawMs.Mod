MODULE Besm2RawMs; (* raw groff tbl tables: -m/--raw-ms-tables *)

(* The Ada BESM2_Fmt.Format_Raw_Ms, a port of besm2-rst.scm's
   process-entity-raw-ms and its process-stat-raw-ms and friends.  The
   name, tagline, description and size are plain reST, as in the grid
   format; the sections are then one groff tbl table in a ".. raw:: ms"
   block, with tbl's own markup ("\fB" bold, "T{"/"T}" text blocks).
   tbl lays out and wraps the columns itself (the "x" column modifier),
   so none of Besm2Layout's column layout is used here. *)

IMPORT Besm2Config, Besm2Entities, Besm2Layout, Besm2Out, Besm2Text, Ropes;

CONST
  (* Indents the groff lines into the ".. raw:: ms" block. *)
  RawPrefix = "   ";

TYPE
  Rope = Ropes.Rope;

VAR
  boldOn, boldOff: Rope;   (* troff's "\fB" and "\fP" *)

(* ---- Output ---- *)

(* RawPrefix, then s, then a newline. *)
PROCEDURE Line(s: ARRAY OF CHAR);
BEGIN Besm2Out.String(RawPrefix); Besm2Out.String(s); Besm2Out.Ln
END Line;

(* Line, for a rope. *)
PROCEDURE RopeLine(r: Rope);
BEGIN Besm2Out.String(RawPrefix); Besm2Out.Rope(r); Besm2Out.Ln
END RopeLine;

(* troff bold, for the table: besm2-rst.scm's tbold, which leaves an
   empty string empty.  Not Besm2Layout.Bold, which is reST's "**",
   used only before the table.  (besm2-rst.scm also defines titalics,
   but never calls it.) *)
PROCEDURE TboldRope(r: Rope): Rope;
BEGIN
  IF r = NIL THEN RETURN NIL END;
  RETURN Ropes.Cat(Ropes.Cat(boldOn, r), boldOff)
END TboldRope;

PROCEDURE Tbold(s: ARRAY OF CHAR): Rope;
BEGIN RETURN TboldRope(Ropes.FromString(s))
END Tbold;

(* The cells of a row, joined with tbl's "#" separator.  The Buffer
   port's Row took NIL for "no third column"; here NIL is an empty
   cell, as a may be for a row whose first column is blank, so two and
   three columns are separate procedures. *)
PROCEDURE Row2(a, b: Rope);
BEGIN RopeLine(Ropes.Cat(Ropes.AppendChar(a, "#"), b))
END Row2;

PROCEDURE Row3(a, b, c: Rope);
BEGIN RopeLine(Ropes.Cat(Ropes.AppendChar(Ropes.Cat(Ropes.AppendChar(a, "#"), b), "#"), c))
END Row3;

(* A total row: blank first column, then bold points and bold label. *)
PROCEDURE TotalRow(points: Rope; label: ARRAY OF CHAR);
BEGIN Row3(NIL, TboldRope(points), Tbold(label))
END TotalRow;

(* A row whose last cell is a "T{ ... T}" text block, so tbl can wrap
   it, after one other column or two. *)
PROCEDURE TextRow2(a, text: Rope);
  VAR r: Rope;
BEGIN
  r := Ropes.AppendChar(a, "#"); Besm2Text.Add(r, "T{");
  RopeLine(r); RopeLine(text); Line("T}")
END TextRow2;

PROCEDURE TextRow3(a, b, text: Rope);
  VAR r: Rope;
BEGIN
  r := Ropes.AppendChar(Ropes.Cat(Ropes.AppendChar(a, "#"), b), "#"); Besm2Text.Add(r, "T{");
  RopeLine(r); RopeLine(text); Line("T}")
END TextRow3;

(* The start of a section: ".T&" before every section but the first,
   which gets the "=" rule above the table instead, then the column
   format. *)
PROCEDURE StartSection(format: ARRAY OF CHAR; VAR firstSectionSeen: BOOLEAN);
BEGIN
  IF firstSectionSeen THEN Line(".T&") END;
  Line(format);
  IF ~firstSectionSeen THEN firstSectionSeen := TRUE; Line("=") END
END StartSection;

(* ---- Numbers ---- *)

PROCEDURE Points(n: INTEGER): Rope;
BEGIN RETURN Besm2Text.Int(n)
END Points;

(* A defect's points, always negative, with MinusGlyph for the sign.
   Inside a tbl text block reST never sees it, so unlike the grid
   format there is no backslash. *)
PROCEDURE DefectPoints(n: INTEGER): Rope;
BEGIN RETURN Ropes.Cat(Besm2Layout.MinusGlyph(), Points(ABS(n)))
END DefectPoints;

(* A total that may be negative, with MinusGlyph for the sign, as
   besm2-rst.scm's points->string (besm-tools commit 5cb3d92). *)
PROCEDURE SignedPoints(n: INTEGER): Rope;
BEGIN
  IF n < 0 THEN RETURN DefectPoints(n) END;
  RETURN Points(n)
END SignedPoints;

(* ---- Cell text: besm2-rst.scm's process-derived-raw-ms and friends ---- *)

(* A line feed made a blank: the Ropes.Mapper of SpaceToNewline. *)
PROCEDURE NewlineToBlank(c: CHAR): CHAR;
BEGIN
  IF c = 0AX THEN RETURN " " END;
  RETURN c
END NewlineToBlank;

(* r with every line feed made a blank: besm2-rst.scm's
   space-to-newline, misleadingly named (it turns newlines into
   blanks).  The same as Besm2Hmm's AllOneLine: a "details: |" block
   scalar's newline can't be left inside a tbl text block. *)
PROCEDURE SpaceToNewline(r: Rope): Rope;
BEGIN RETURN Ropes.Map(r, NewlineToBlank)
END SpaceToNewline;

(* besm2-rst.scm's derived-abbreviations, as in Besm2Grid: only the
   grid and raw ms formats expand them. *)
PROCEDURE ExpandDerivedName(name: Rope): Rope;
BEGIN
  IF Ropes.EqualString(name, "ACV") THEN RETURN Ropes.FromString("Attack Combat Value")
  ELSIF Ropes.EqualString(name, "DCV") THEN RETURN Ropes.FromString("Defence Combat Value")
  ELSIF Ropes.EqualString(name, "DM") THEN RETURN Ropes.FromString("Damage Multiplier")
  ELSIF Ropes.EqualString(name, "HP") THEN RETURN Ropes.FromString("Health Points")
  ELSIF Ropes.EqualString(name, "EP") THEN RETURN Ropes.FromString("Energy Points")
  ELSIF Ropes.EqualString(name, "SV") THEN RETURN Ropes.FromString("Shock Value")
  ELSIF Ropes.EqualString(name, "AR") THEN RETURN Ropes.FromString("Armour Rating")
  END;
  RETURN name
END ExpandDerivedName;

(* "NAME (TEXT)". *)
PROCEDURE Parens(name, text: Rope): Rope;
  VAR r: Rope;
BEGIN
  r := name; Besm2Text.Add(r, " (");
  RETURN Ropes.AppendChar(Ropes.Cat(r, text), ")")
END Parens;

(* "NAME (DETAILS)", or just NAME if there are no details. *)
PROCEDURE WithDetails(name, details: Rope): Rope;
BEGIN
  IF details = NIL THEN RETURN name END;
  RETURN Parens(name, details)
END WithDetails;

(* "NAME (A, B)", or just NAME if l has no items.  The test is the
   number of items, as in the Ada version and besm2-rst.scm, not the
   joined text: a list of one empty string gives "NAME ()".  (The
   Buffer port tested the text; PLAN.md, step 7.) *)
PROCEDURE WithList(name: Rope; l: Besm2Text.List): Rope;
BEGIN
  IF l.n = 0 THEN RETURN name END;
  RETURN Parens(name, Besm2Text.Join(l, ", "))
END WithList;

(* ---- ProcessEntity ---- *)

(* Writes e.  entityNo is 1 for the first entity of a file, 2 for the
   second, and so on: entities after the first are underlined with
   -U/--subunderliner's character, if given. *)
PROCEDURE ProcessEntity*(e: Besm2Entities.Entity; entityNo: INTEGER);
  VAR i: INTEGER; underline: CHAR; paragraphSeen, firstSectionSeen: BOOLEAN;
    s: Besm2Entities.Stat; d: Besm2Entities.Derived; a: Besm2Entities.Attribute;
    df: Besm2Entities.Defect; sk: Besm2Entities.Skill;
BEGIN
  paragraphSeen := FALSE; firstSectionSeen := FALSE;

  IF e.hasName THEN
    IF (entityNo > 1) & (Besm2Config.subunderliner # 0X) THEN underline := Besm2Config.subunderliner
    ELSE underline := Besm2Config.underliner
    END;
    Besm2Out.Rope(e.name); Besm2Out.Ln;
    (* As long as the name in bytes, as in the Ada version. *)
    Besm2Out.Repeat(underline, Ropes.Length(e.name)); Besm2Out.Ln;
    Besm2Out.Ln
  END;

  IF e.hasTagline THEN
    paragraphSeen := TRUE;
    Besm2Out.Rope(Besm2Layout.Italics(e.tagline)); Besm2Out.Ln; Besm2Out.Ln
  END;

  IF ~Besm2Config.omitEntityDescription & e.hasDescription THEN
    paragraphSeen := TRUE;
    Besm2Out.Rope(e.description); Besm2Out.Ln; Besm2Out.Ln;
    IF Besm2Config.pageAfterDescription THEN
      Besm2Out.String(".. raw:: ms"); Besm2Out.Ln; Besm2Out.Ln;
      Besm2Out.String("   .bp"); Besm2Out.Ln; Besm2Out.Ln
    END
  END;

  IF e.hasSize THEN
    paragraphSeen := TRUE;
    Besm2Out.Rope(Besm2Layout.Bold(Ropes.FromString("Size:"))); Besm2Out.Char(" "); Besm2Out.Rope(e.size);
    Besm2Out.Ln; Besm2Out.Ln
  END;

  Besm2Out.String(".. raw:: ms"); Besm2Out.Ln; Besm2Out.Ln;

  (* groff from here on.  With no paragraph before it, the table gets
     an ".LP" of its own. *)
  IF ~paragraphSeen THEN Line(".LP") END;
  Line(".TS");
  Line("tab(#) ;");

  IF e.stats.n > 0 THEN
    StartSection("c c lx .", firstSectionSeen);
    Row3(Tbold("VALUE"), Tbold("POINTS"), Tbold("STAT"));
    FOR i := 0 TO e.stats.n - 1 DO
      s := e.stats.items[i](Besm2Entities.Stat);
      Row3(s.value, Points(s.points), s.name)
    END;
    IF Besm2Config.showSubtotals THEN TotalRow(Points(e.statsTotal), "STATS TOTAL") END;
    Besm2Out.Ln
  END;

  IF e.derived.n > 0 THEN
    StartSection("c l sx .", firstSectionSeen);
    Row2(Tbold("VALUE"), Tbold("DERIVED VALUE"));
    FOR i := 0 TO e.derived.n - 1 DO
      d := e.derived.items[i](Besm2Entities.Derived);
      TextRow2(d.value, WithList(ExpandDerivedName(d.name), d.alternatives))
    END;
    Besm2Out.Ln
  END;

  IF e.attributes.n > 0 THEN
    StartSection("c c lx .", firstSectionSeen);
    Row3(Tbold("LEVEL"), Tbold("POINTS"), Tbold("ATTRIBUTE"));
    FOR i := 0 TO e.attributes.n - 1 DO
      a := e.attributes.items[i](Besm2Entities.Attribute);
      TextRow3(a.level, Points(a.points), WithDetails(a.name, SpaceToNewline(a.details)))
    END;
    IF Besm2Config.showSubtotals THEN TotalRow(Points(e.attributesTotal), "ATTRIBUTES TOTAL") END;
    Besm2Out.Ln
  END;

  IF e.defects.n > 0 THEN
    StartSection("c c lx .", firstSectionSeen);
    Row3(NIL, Tbold("POINTS"), Tbold("DEFECT"));
    FOR i := 0 TO e.defects.n - 1 DO
      df := e.defects.items[i](Besm2Entities.Defect);
      TextRow3(NIL, DefectPoints(df.points), WithDetails(df.name, SpaceToNewline(df.details)))
    END;
    IF Besm2Config.showSubtotals THEN TotalRow(SignedPoints(e.defectsTotal), "DEFECTS TOTAL") END;
    Besm2Out.Ln
  END;

  IF e.skills.n > 0 THEN
    StartSection("c c lx .", firstSectionSeen);
    Row3(Tbold("LEVEL"), Tbold("POINTS"), Tbold("SKILL"));
    FOR i := 0 TO e.skills.n - 1 DO
      sk := e.skills.items[i](Besm2Entities.Skill);
      TextRow3(sk.level, Points(sk.points), WithList(sk.name, sk.specialisations))
    END;
    IF Besm2Config.showSubtotals THEN TotalRow(Points(e.skillsTotal), "SKILL POINTS TOTAL") END;
    Besm2Out.Ln
  END;

  (* The total row has three columns, so it needs a format of its own
     when there was no section, or the last was the derived values'
     two. *)
  IF ~firstSectionSeen
     OR (e.derived.n > 0) & (e.attributes.n = 0) & (e.defects.n = 0) & (e.skills.n = 0) THEN
    StartSection("c c lx .", firstSectionSeen)
  END;
  TotalRow(SignedPoints(e.entityTotal), "TOTAL");
  Line("=");
  Line(".TE");
  (* The blank line ends the raw block before the next entity's name. *)
  Besm2Out.Ln;

  Besm2Layout.Notes(e.notes)
END ProcessEntity;

BEGIN
  boldOn := Ropes.FromString("\fB"); boldOff := Ropes.FromString("\fP")
END Besm2RawMs.
