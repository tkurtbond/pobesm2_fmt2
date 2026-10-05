MODULE Besm2Terse; (* The terse format (-t/--terse) *)

(* The Ada BESM2_Fmt.Format_Terse: the terse format of the BESM 1E and
   2E books, a port of besm2-rst.scm's process-entity-terse.  Each
   section is one paragraph: a bold heading, " — ", and the items
   separated by ", ". *)

IMPORT Besm2Config, Besm2Entities, Besm2Layout, Besm2Out, Besm2Text, Ropes;

TYPE
  Rope = Ropes.Rope;

(* "N CP" for points, "N BP" for a negative number (bonus points), or
   "N MP"/"N MBP" for a mecha: the number is always written without a
   sign. *)
PROCEDURE LabelPoints(points: INTEGER; mecha: BOOLEAN): Rope;
  VAR r: Rope;
BEGIN
  r := Ropes.AppendChar(Besm2Text.Int(ABS(points)), " ");
  IF mecha THEN
    IF points < 0 THEN Besm2Text.Add(r, "MBP") ELSE Besm2Text.Add(r, "MP") END
  ELSE
    IF points < 0 THEN Besm2Text.Add(r, "BP") ELSE Besm2Text.Add(r, "CP") END
  END;
  RETURN r
END LabelPoints;

(* "NAME LEVEL", "NAME — LEVEL" under -M/--em-dash, with "Level " before
   LEVEL under -l/--level: the emphasized part of an attribute or
   skill. *)
PROCEDURE NameAndLevel(name, level: Rope): Rope;
  VAR r: Rope;
BEGIN
  r := name;
  IF Besm2Config.emDash THEN Besm2Text.Add(r, " — ") ELSE r := Ropes.AppendChar(r, " ") END;
  IF Besm2Config.level THEN Besm2Text.Add(r, "Level ") END;
  RETURN Ropes.Cat(r, level)
END NameAndLevel;

(* r, then " (", details and ". " if there are any details, the points,
   and ")": the end of an attribute or a defect. *)
PROCEDURE WithDetails(r, details: Rope; points: INTEGER; mecha: BOOLEAN): Rope;
BEGIN
  Besm2Text.Add(r, " (");
  IF details # NIL THEN r := Ropes.Cat(r, details); Besm2Text.Add(r, ". ") END;
  r := Ropes.Cat(r, LabelPoints(points, mecha));
  RETURN Ropes.AppendChar(r, ")")
END WithDetails;

(* ---- Items: besm2-rst.scm's process-stat-terse and friends ---- *)

PROCEDURE Stat(s: Besm2Entities.Stat; mecha: BOOLEAN): Rope;
  VAR r: Rope;
BEGIN
  r := Ropes.Cat(Ropes.AppendChar(s.name, " "), s.value);
  Besm2Text.Add(r, " ("); r := Ropes.Cat(r, LabelPoints(s.points, mecha));
  RETURN Ropes.AppendChar(r, ")")
END Stat;

PROCEDURE Derived(d: Besm2Entities.Derived): Rope;
  VAR r: Rope;
BEGIN
  r := Ropes.Cat(Ropes.AppendChar(d.name, " "), d.value);
  IF d.alternatives.n > 0 THEN
    Besm2Text.Add(r, " ("); r := Ropes.Cat(r, Besm2Text.Join(d.alternatives, ", "));
    r := Ropes.AppendChar(r, ")")
  END;
  RETURN r
END Derived;

PROCEDURE Attribute(a: Besm2Entities.Attribute; mecha: BOOLEAN): Rope;
BEGIN
  RETURN WithDetails(Besm2Layout.Emphasizing(NameAndLevel(a.name, a.level)), a.details,
                     a.points, mecha)
END Attribute;

PROCEDURE Defect(d: Besm2Entities.Defect; mecha: BOOLEAN): Rope;
BEGIN
  RETURN WithDetails(Besm2Layout.Emphasizing(d.name), d.details, d.points, mecha)
END Defect;

PROCEDURE Skill(s: Besm2Entities.Skill): Rope;
  VAR r: Rope;
BEGIN
  r := Besm2Layout.Emphasizing(NameAndLevel(s.name, s.level));
  Besm2Text.Add(r, " (");
  IF s.specialisations.n > 0 THEN
    r := Ropes.Cat(r, Besm2Text.Join(s.specialisations, ", ")); Besm2Text.Add(r, ". ")
  END;
  Besm2Text.AddInt(r, s.points); Besm2Text.Add(r, " SP)");
  RETURN r
END Skill;

(* ---- Sections ---- *)

(* reST bold of a literal, for the headings. *)
PROCEDURE Bold(s: ARRAY OF CHAR): Rope;
BEGIN RETURN Besm2Layout.Bold(Ropes.FromString(s))
END Bold;

(* The items of l, formatted by kind, separated by ", ", then a blank
   line. *)
PROCEDURE Items(l: Besm2Entities.List; mecha: BOOLEAN);
  VAR i: INTEGER; x: Besm2Entities.Named;
BEGIN
  FOR i := 0 TO l.n - 1 DO
    IF i > 0 THEN Besm2Out.String(", ") END;
    x := l.items[i];
    WITH x: Besm2Entities.Stat DO Besm2Out.Rope(Stat(x, mecha))
    | x: Besm2Entities.Derived DO Besm2Out.Rope(Derived(x))
    | x: Besm2Entities.Attribute DO Besm2Out.Rope(Attribute(x, mecha))
    | x: Besm2Entities.Defect DO Besm2Out.Rope(Defect(x, mecha))
    | x: Besm2Entities.Skill DO Besm2Out.Rope(Skill(x))
    END
  END;
  Besm2Out.Ln; Besm2Out.Ln
END Items;

(* " (N CP)" or the like after a section heading, under -s/--subtotals. *)
PROCEDURE Subtotal(points: INTEGER; mecha: BOOLEAN);
BEGIN
  IF Besm2Config.showSubtotals THEN
    Besm2Out.String(" ("); Besm2Out.Rope(LabelPoints(points, mecha)); Besm2Out.Char(")")
  END
END Subtotal;

(* Writes e.  entityNo is 1 for the first entity of a file, 2 for the
   second, and so on: entities after the first are underlined with
   -U/--subunderliner's character, if given. *)
PROCEDURE ProcessEntity*(e: Besm2Entities.Entity; entityNo: INTEGER);
  VAR header: Rope; underline: CHAR;
BEGIN
  IF e.hasName THEN
    header := e.name; Besm2Text.Add(header, " (");
    header := Ropes.AppendChar(Ropes.Cat(header, LabelPoints(e.entityTotal, e.mecha)), ")");
    IF (entityNo > 1) & (Besm2Config.subunderliner # 0X) THEN underline := Besm2Config.subunderliner
    ELSE underline := Besm2Config.underliner
    END;
    Besm2Out.Rope(header); Besm2Out.Ln;
    (* The underline is as long as the header in bytes, not characters,
       as in the Ada version (Header'Length). *)
    Besm2Out.Repeat(underline, Ropes.Length(header)); Besm2Out.Ln;
    Besm2Out.Ln
  ELSE
    Besm2Out.Rope(LabelPoints(e.entityTotal, e.mecha)); Besm2Out.Ln;
    Besm2Out.Ln
  END;

  IF e.hasTagline THEN
    Besm2Out.Rope(Besm2Layout.Italics(e.tagline)); Besm2Out.Ln; Besm2Out.Ln
  END;

  IF e.hasDescription & ~Besm2Config.omitEntityDescription THEN
    Besm2Out.Rope(e.description); Besm2Out.Ln; Besm2Out.Ln;
    IF Besm2Config.pageAfterDescription THEN
      Besm2Out.String(".. raw:: ms"); Besm2Out.Ln; Besm2Out.Ln;
      Besm2Out.String("   .bp"); Besm2Out.Ln; Besm2Out.Ln
    END
  END;

  IF e.hasSize THEN
    Besm2Out.Rope(Bold("Size:")); Besm2Out.Char(" "); Besm2Out.Rope(e.size);
    Besm2Out.Ln; Besm2Out.Ln
  END;

  IF e.stats.n > 0 THEN
    Besm2Out.Rope(Bold("Statistics"));
    Subtotal(e.statsTotal, e.mecha);
    Besm2Out.String(" — "); Besm2Out.Ln;
    Items(e.stats, e.mecha)
  END;

  IF e.derived.n > 0 THEN
    (* No line break after this heading, unlike the others. *)
    Besm2Out.Rope(Bold("Derived Values")); Besm2Out.String(" — ");
    Items(e.derived, e.mecha)
  END;

  IF e.attributes.n > 0 THEN
    IF e.mecha THEN Besm2Out.Rope(Bold("Mecha Sub-Attributes"))
    ELSE Besm2Out.Rope(Bold("Attributes"))
    END;
    Subtotal(e.attributesTotal, e.mecha);
    Besm2Out.String(" — "); Besm2Out.Ln;
    Items(e.attributes, e.mecha)
  END;

  IF e.defects.n > 0 THEN
    IF e.mecha THEN Besm2Out.Rope(Bold("Mecha Defects"))
    ELSE Besm2Out.Rope(Bold("Defects"))
    END;
    Subtotal(e.defectsTotal, e.mecha);
    Besm2Out.String(" — "); Besm2Out.Ln;
    Items(e.defects, e.mecha)
  END;

  IF e.skills.n > 0 THEN
    Besm2Out.Rope(Bold("Skills"));
    IF Besm2Config.showSubtotals THEN
      Besm2Out.String(" ("); Besm2Out.Rope(Besm2Text.Int(e.skillsTotal)); Besm2Out.String(" SP)")
    END;
    Besm2Out.String(" — "); Besm2Out.Ln;
    Items(e.skills, e.mecha)
  END
END ProcessEntity;

END Besm2Terse.
