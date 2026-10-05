MODULE Besm2Grid; (* reST grid tables: the default format *)

(* The Ada BESM2_Fmt.Format_Grid, a port of besm2-rst.scm's
   process-entity and its process-stat and friends: each section of an
   entity is a reST grid table, laid out by Besm2Layout.  Row2, Row3,
   Sep2 and so on match besm2-rst.scm's helpers of the same names, so
   this reads next to process-entity with little translation. *)

IMPORT Besm2Config, Besm2Entities, Besm2Layout, Besm2Out, Besm2Text, Ropes;

TYPE
  Rope = Ropes.Rope;

(* ---- besm2-rst.scm's row and separator helpers ---- *)

(* A NIL column, the empty rope, is an empty cell. *)

PROCEDURE Row2(a, b: Rope);
BEGIN Besm2Layout.Row2(a, b)
END Row2;

PROCEDURE Row3(a, b, c: Rope);
BEGIN Besm2Layout.Row3(a, b, c)
END Row3;

PROCEDURE Sep2;
BEGIN Besm2Layout.SeparatorLine(2, "-")
END Sep2;

PROCEDURE Sep3;
BEGIN Besm2Layout.SeparatorLine(3, "-")
END Sep3;

PROCEDURE Headsep2;
BEGIN Besm2Layout.SeparatorLine(2, Besm2Config.headSep)
END Headsep2;

PROCEDURE Headsep3;
BEGIN Besm2Layout.SeparatorLine(3, Besm2Config.headSep)
END Headsep3;

(* After a section: a row of the one table under -1/--one, else a blank
   line between tables. *)
PROCEDURE EmptyOrBlankLine;
BEGIN
  IF Besm2Config.oneTable THEN Besm2Layout.EmptyRow ELSE Besm2Out.Ln END
END EmptyOrBlankLine;

(* Hbolding of a literal, and of a rope, for header and total cells. *)
PROCEDURE H(s: ARRAY OF CHAR): Rope;
BEGIN RETURN Besm2Layout.Hbolding(Ropes.FromString(s))
END H;

PROCEDURE HS(r: Rope): Rope;
BEGIN RETURN Besm2Layout.Hbolding(r)
END HS;

(* ---- Numbers ---- *)

PROCEDURE Points(n: INTEGER): Rope;
BEGIN RETURN Besm2Text.Int(n)
END Points;

(* A defect's points, always negative, with a backslash before the
   sign, since reST would otherwise take a leading "-" for a bullet.
   besm2-rst.scm's process-defect adds the backslash whatever the sign,
   and so does this.  The sign is MinusGlyph, not Int's "-". *)
PROCEDURE DefectPoints(n: INTEGER): Rope;
BEGIN
  RETURN Ropes.Cat(Ropes.Cat(Ropes.FromChar("\"), Besm2Layout.MinusGlyph()), Points(ABS(n)))
END DefectPoints;

(* A total that may be negative: the defects total, and the entity
   total when defects outweigh the rest.  With MinusGlyph for the sign,
   as besm2-rst.scm's points->string (besm-tools commit 5cb3d92). *)
PROCEDURE SignedPoints(n: INTEGER): Rope;
BEGIN
  IF n < 0 THEN RETURN Ropes.Cat(Besm2Layout.MinusGlyph(), Points(ABS(n))) END;
  RETURN Points(n)
END SignedPoints;

(* ---- Cell text: besm2-rst.scm's process-derived and friends ---- *)

(* besm2-rst.scm's derived-abbreviations.  Only the grid and raw ms
   formats expand them; the terse output keeps "ACV" and so on. *)
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

PROCEDURE DerivedDescription(d: Besm2Entities.Derived): Rope;
BEGIN RETURN WithList(ExpandDerivedName(d.name), d.alternatives)
END DerivedDescription;

PROCEDURE SkillDescription(s: Besm2Entities.Skill): Rope;
BEGIN RETURN WithList(s.name, s.specialisations)
END SkillDescription;

(* ---- ProcessEntity ---- *)

(* Writes e.  entityNo is 1 for the first entity of a file, 2 for the
   second, and so on: entities after the first are underlined with
   -U/--subunderliner's character, if given. *)
PROCEDURE ProcessEntity*(e: Besm2Entities.Entity; entityNo: INTEGER);
  VAR i: INTEGER; underline: CHAR; s: Besm2Entities.Stat; d: Besm2Entities.Derived;
    a: Besm2Entities.Attribute; df: Besm2Entities.Defect; sk: Besm2Entities.Skill;
BEGIN
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
    Besm2Out.Rope(Besm2Layout.Italics(e.tagline)); Besm2Out.Ln; Besm2Out.Ln
  END;

  IF ~Besm2Config.omitEntityDescription & e.hasDescription THEN
    Besm2Out.Rope(e.description); Besm2Out.Ln; Besm2Out.Ln;
    IF Besm2Config.pageAfterDescription THEN
      Besm2Out.String(".. raw:: ms"); Besm2Out.Ln; Besm2Out.Ln;
      Besm2Out.String("   .bp"); Besm2Out.Ln; Besm2Out.Ln
    END
  END;

  IF e.hasSize THEN
    Besm2Out.Rope(Besm2Layout.Bold(Ropes.FromString("Size:"))); Besm2Out.Char(" "); Besm2Out.Rope(e.size);
    Besm2Out.Ln; Besm2Out.Ln
  END;

  IF e.stats.n > 0 THEN
    Sep3;
    Row3(H("VALUE"), H("POINTS"), H("STAT"));
    Headsep3;
    FOR i := 0 TO e.stats.n - 1 DO
      s := e.stats.items[i](Besm2Entities.Stat);
      Row3(s.value, Points(s.points), s.name);
      Sep3
    END;
    IF Besm2Config.showSubtotals THEN
      Row3(NIL, HS(Points(e.statsTotal)), H("STATS TOTAL"));
      Sep3
    END;
    EmptyOrBlankLine
  END;

  IF e.derived.n > 0 THEN
    Sep2;
    Row2(H("VALUE"), H("DERIVED VALUE"));
    Headsep2;
    FOR i := 0 TO e.derived.n - 1 DO
      d := e.derived.items[i](Besm2Entities.Derived);
      Row2(d.value, DerivedDescription(d));
      Sep2
    END;
    EmptyOrBlankLine
  END;

  IF e.attributes.n > 0 THEN
    Sep3;
    Row3(H("LEVEL"), H("POINTS"), H("ATTRIBUTE"));
    Headsep3;
    FOR i := 0 TO e.attributes.n - 1 DO
      a := e.attributes.items[i](Besm2Entities.Attribute);
      Row3(a.level, Points(a.points), WithDetails(a.name, a.details));
      Sep3
    END;
    IF Besm2Config.showSubtotals THEN
      Row3(NIL, HS(Points(e.attributesTotal)), H("ATTRIBUTES TOTAL"));
      Sep3
    END;
    EmptyOrBlankLine
  END;

  IF e.defects.n > 0 THEN
    Sep3;
    Row3(NIL, H("POINTS"), H("DEFECT"));
    Headsep3;
    FOR i := 0 TO e.defects.n - 1 DO
      df := e.defects.items[i](Besm2Entities.Defect);
      Row3(NIL, DefectPoints(df.points), WithDetails(df.name, df.details));
      Sep3
    END;
    IF Besm2Config.showSubtotals THEN
      Row3(NIL, HS(SignedPoints(e.defectsTotal)), H("DEFECTS TOTAL"));
      Sep3
    END;
    EmptyOrBlankLine
  END;

  IF e.skills.n > 0 THEN
    Sep3;
    Row3(H("LEVEL"), H("POINTS"), H("SKILL"));
    Headsep3;
    FOR i := 0 TO e.skills.n - 1 DO
      sk := e.skills.items[i](Besm2Entities.Skill);
      Row3(sk.level, Points(sk.points), SkillDescription(sk));
      Sep3
    END;
    IF Besm2Config.showSubtotals THEN
      Row3(NIL, HS(Points(e.skillsTotal)), H("SKILL POINTS TOTAL"));
      Sep3
    END;
    EmptyOrBlankLine
  END;

  (* The grand total: always shown, and followed by a plain blank line
     even under -1/--one, as in besm2-rst.scm. *)
  Sep3;
  Row3(NIL, HS(SignedPoints(e.entityTotal)), H("TOTAL"));
  Sep3;
  Besm2Out.Ln
END ProcessEntity;

END Besm2Grid.
