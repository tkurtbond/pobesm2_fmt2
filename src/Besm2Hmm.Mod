MODULE Besm2Hmm; (* The h-m-m outline format (-H/--hmm) *)

(* The Ada BESM2_Fmt.Format_Hmm, a port of besm2-rst.scm's
   process-entity-hmm and its process-stat-hmm and friends: a
   tab-indented outline for h-m-m, one node per line.  The item text is
   the terse format's, except that details are flattened onto one line;
   the section headings are like terse's, without the " — ".

   Indentation starts from -L/--hmm-depth for every entity.  In
   besm2-rst.scm *hmm-depth* is a parameter, and each deeper level a
   parameterize whose extent ends with the entity, so it never builds
   up from one entity to the next.  The -R/--hmm-root line is written
   once per run, by the main module, not here. *)

IMPORT Besm2Config, Besm2Entities, Besm2Layout, Besm2Out, Besm2Text, Ropes;

TYPE
  Rope = Ropes.Rope;

PROCEDURE Indent(depth: INTEGER);
BEGIN Besm2Out.Repeat(09X, depth)
END Indent;

(* A line feed made a blank: the Ropes.Mapper of AllOneLine. *)
PROCEDURE NewlineToBlank(c: CHAR): CHAR;
BEGIN
  IF c = 0AX THEN RETURN " " END;
  RETURN c
END NewlineToBlank;

(* r with every line feed made a blank: besm2-rst.scm's all-one-line,
   which splits on newlines and joins with blanks (two newlines in a row
   give two blanks).  An h-m-m node is one line, so a newline inside a
   tagline, description or details -- from a "details: |" block scalar,
   as in FV2021-Coleopteran-2e.yaml's "Weapon: Rocket Pod" -- can't be
   written as it is. *)
PROCEDURE AllOneLine(r: Rope): Rope;
BEGIN RETURN Ropes.Map(r, NewlineToBlank)
END AllOneLine;

(* "N CP", "N BP", "N MP" or "N MBP", as in Besm2Terse. *)
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

(* "NAME LEVEL" (with -M's " — " and -l's "Level "), emphasized under -b
   or -i.  Only name and level are emphasized, in skills too:
   besm2-rst.scm's process-skill-hmm emphasized the rest of the line as
   well, a bug fixed upstream (besm-tools b04abb5) and in the Ada
   version. *)
PROCEDURE NameAndLevel(name, level: Rope): Rope;
  VAR r: Rope;
BEGIN
  r := name;
  IF Besm2Config.emDash THEN Besm2Text.Add(r, " — ") ELSE r := Ropes.AppendChar(r, " ") END;
  IF Besm2Config.level THEN Besm2Text.Add(r, "Level ") END;
  RETURN Besm2Layout.Emphasizing(Ropes.Cat(r, level))
END NameAndLevel;

(* r, then " (", the details, flattened, and ". " if there are any
   details, the points, and ")": the end of an attribute or a defect. *)
PROCEDURE WithDetails(r, details: Rope; points: INTEGER; mecha: BOOLEAN): Rope;
BEGIN
  Besm2Text.Add(r, " (");
  IF details # NIL THEN r := Ropes.Cat(r, AllOneLine(details)); Besm2Text.Add(r, ". ") END;
  r := Ropes.Cat(r, LabelPoints(points, mecha));
  RETURN Ropes.AppendChar(r, ")")
END WithDetails;

(* ---- Items: besm2-rst.scm's process-stat-hmm and friends ---- *)

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
BEGIN RETURN WithDetails(NameAndLevel(a.name, a.level), a.details, a.points, mecha)
END Attribute;

PROCEDURE Defect(d: Besm2Entities.Defect; mecha: BOOLEAN): Rope;
BEGIN RETURN WithDetails(Besm2Layout.Emphasizing(d.name), d.details, d.points, mecha)
END Defect;

PROCEDURE Skill(s: Besm2Entities.Skill): Rope;
  VAR r: Rope;
BEGIN
  r := NameAndLevel(s.name, s.level);
  Besm2Text.Add(r, " (");
  IF s.specialisations.n > 0 THEN
    r := Ropes.Cat(r, Besm2Text.Join(s.specialisations, ", ")); Besm2Text.Add(r, ". ")
  END;
  Besm2Text.AddInt(r, s.points); Besm2Text.Add(r, " SP)");
  RETURN r
END Skill;

(* ---- Sections ---- *)

(* The items of l, on one line at depth, separated by ", ", or each on
   its own line at depth under -S/--hmm-separate. *)
PROCEDURE Items(l: Besm2Entities.List; mecha: BOOLEAN; depth: INTEGER);
  VAR i: INTEGER; x: Besm2Entities.Named;
BEGIN
  Indent(depth);
  FOR i := 0 TO l.n - 1 DO
    IF i > 0 THEN
      IF Besm2Config.hmmSeparate THEN Besm2Out.Ln; Indent(depth)
      ELSE Besm2Out.String(", ")
      END
    END;
    x := l.items[i];
    WITH x: Besm2Entities.Stat DO Besm2Out.Rope(Stat(x, mecha))
    | x: Besm2Entities.Derived DO Besm2Out.Rope(Derived(x))
    | x: Besm2Entities.Attribute DO Besm2Out.Rope(Attribute(x, mecha))
    | x: Besm2Entities.Defect DO Besm2Out.Rope(Defect(x, mecha))
    | x: Besm2Entities.Skill DO Besm2Out.Rope(Skill(x))
    END
  END;
  Besm2Out.Ln
END Items;

(* A section heading at depth, in bold. *)
PROCEDURE Heading(depth: INTEGER; text: ARRAY OF CHAR);
BEGIN Indent(depth); Besm2Out.Rope(Besm2Layout.Bold(Ropes.FromString(text)))
END Heading;

(* " (N CP)" or the like, under -s/--subtotals. *)
PROCEDURE Subtotal(points: INTEGER; mecha: BOOLEAN);
BEGIN
  IF Besm2Config.showSubtotals THEN
    Besm2Out.String(" ("); Besm2Out.Rope(LabelPoints(points, mecha)); Besm2Out.Char(")")
  END
END Subtotal;

(* Writes e.  entityNo is unused -- an outline has no underlined
   headers -- and taken only so that every format is called the same
   way, as in the Ada version. *)
PROCEDURE ProcessEntity*(e: Besm2Entities.Entity; entityNo: INTEGER);
  VAR d1, d2, d3: INTEGER;
BEGIN
  d1 := Besm2Config.hmmDepth + 1;   (* the entity *)
  d2 := d1 + 1;                     (* its sections *)
  d3 := d2 + 1;                     (* their items *)

  Indent(d1);
  IF e.hasName THEN
    Besm2Out.Rope(e.name); Besm2Out.String(" (");
    Besm2Out.Rope(LabelPoints(e.entityTotal, e.mecha)); Besm2Out.Char(")")
  ELSE
    Besm2Out.Rope(LabelPoints(e.entityTotal, e.mecha))
  END;
  Besm2Out.Ln;

  IF e.hasTagline THEN
    Indent(d2); Besm2Out.Rope(Besm2Layout.Italics(AllOneLine(e.tagline))); Besm2Out.Ln
  END;

  IF ~Besm2Config.omitEntityDescription & e.hasDescription THEN
    Indent(d2); Besm2Out.Rope(AllOneLine(e.description)); Besm2Out.Ln
  END;

  IF e.hasSize THEN
    Indent(d2); Besm2Out.Rope(Besm2Layout.Bold(Ropes.FromString("Size:"))); Besm2Out.Char(" "); Besm2Out.Rope(e.size);
    Besm2Out.Ln
  END;

  IF e.stats.n > 0 THEN
    Heading(d2, "Statistics");
    Subtotal(e.statsTotal, e.mecha);
    Besm2Out.Ln;
    Items(e.stats, e.mecha, d3)
  END;

  IF e.derived.n > 0 THEN
    Heading(d2, "Derived Values"); Besm2Out.Ln;
    Items(e.derived, e.mecha, d3)
  END;

  IF e.attributes.n > 0 THEN
    IF e.mecha THEN Heading(d2, "Mecha Sub-Attributes") ELSE Heading(d2, "Attributes") END;
    Subtotal(e.attributesTotal, e.mecha); Besm2Out.Ln;
    Items(e.attributes, e.mecha, d3)
  END;

  IF e.defects.n > 0 THEN
    IF e.mecha THEN Heading(d2, "Mecha Defects") ELSE Heading(d2, "Defects") END;
    Subtotal(e.defectsTotal, e.mecha); Besm2Out.Ln;
    Items(e.defects, e.mecha, d3)
  END;

  IF e.skills.n > 0 THEN
    Heading(d2, "Skills");
    IF Besm2Config.showSubtotals THEN
      Besm2Out.String(" ("); Besm2Out.Rope(Besm2Text.Int(e.skillsTotal)); Besm2Out.String(" SP)")
    END;
    Besm2Out.Ln;
    Items(e.skills, e.mecha, d3)
  END
END ProcessEntity;

END Besm2Hmm.
