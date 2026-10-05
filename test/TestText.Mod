MODULE TestText; (* Besm2Text: integers, widths, trimming, lists, sorting, flat copies *)

(* The checks of the Buffer port's TestStr that still have a meaning,
   plus ones for NIL, the empty rope, and for ropes of more than one
   leaf: Ropes.Cat merges leaves up to Ropes.ShortLeafLength characters,
   so a rope built from short pieces is often a single leaf, which
   would hide a bug in code that walks leaves.  Long builds one that
   isn't. *)

IMPORT Besm2Text, Check, Ropes;

TYPE
  Rope = Ropes.Rope;

VAR
  l: Besm2Text.List;
  r, t: Rope;
  s: Besm2Text.String;
  y: ARRAY 2 OF CHAR;
  i: INTEGER;

PROCEDURE Is(r: Rope; t: ARRAY OF CHAR): BOOLEAN;
BEGIN RETURN Ropes.EqualString(r, t)
END Is;

PROCEDURE R(s: ARRAY OF CHAR): Rope;
BEGIN RETURN Ropes.FromString(s)
END R;

PROCEDURE Less(a, b: ARRAY OF CHAR): BOOLEAN;
BEGIN RETURN Besm2Text.LessCI(R(a), R(b))
END Less;

(* a, b and c as a rope of three leaves, each too long to merge. *)
PROCEDURE Long(a, b, c: ARRAY OF CHAR): Rope;
BEGIN RETURN Ropes.Cat(Ropes.Cat(R(a), R(b)), R(c))
END Long;

BEGIN
  Check.Check(Ropes.Length(R("Body")) = 4, "Length of ASCII text");
  Check.Check(R("") = NIL, "the empty rope is NIL");
  (* "×" is C3 97; "“" is E2 80 9C. *)
  Check.Check(Ropes.Length(R("Shots ×2")) = 9, "Length counts bytes");
  Check.Check(Besm2Text.DisplayLength(R("Shots ×2")) = 8, "DisplayLength counts UTF-8 characters");
  Check.Check(Besm2Text.DisplayLength(R("“")) = 1, "DisplayLength of a 3-byte character");
  Check.Check(Besm2Text.DisplayLength(NIL) = 0, "DisplayLength of the empty rope");
  r := Long("Limited Shots ×2 and ", "“quoted” text that is long, ", "Élan and more to the end");
  Check.Check(Ropes.Depth(r) = 2, "Long builds a rope of several leaves");
  Check.Check((Ropes.Length(r) = 79) & (Besm2Text.DisplayLength(r) = 73),
    "DisplayLength across several leaves");

  Check.Check(Is(Besm2Text.Trim(R("  a b  ")), "a b"), "Trim strips blanks at both ends only");
  r := Ropes.AppendChar(R("text"), 0AX);
  Check.Check(Is(Besm2Text.Trim(r), "text"),
    "Trim strips the newline a literal block scalar ends with");
  r := Ropes.AppendChar(Ropes.AppendChar(Ropes.FromChar(09X), 0DX), 0AX);
  Besm2Text.Add(r, " x"); r := Ropes.AppendChar(r, 0AX); Besm2Text.Add(r, "y"); r := Ropes.AppendChar(r, 09X);
  t := Ropes.AppendChar(R("x"), 0AX); Besm2Text.Add(t, "y");
  Check.Check(Ropes.Equal(Besm2Text.Trim(r), t), "Trim strips tab, CR and LF, not inside");
  Check.Check(Besm2Text.Trim(R("   ")) = NIL, "Trim of all blanks is empty");
  Check.Check(Besm2Text.Trim(NIL) = NIL, "Trim of the empty rope");
  r := R("untouched");
  Check.Check(Besm2Text.Trim(r) = r, "Trim returns a rope with nothing to strip as it is");
  r := Ropes.AppendChar(Ropes.Cat(Ropes.FromChar(0CX), R("page")), 0CX);
  Check.Check(Ropes.Length(Besm2Text.Trim(r)) = 6, "Trim keeps form feeds, which Ropes.Trim strips");
  Check.Check(Ropes.Length(Ropes.Trim(r)) = 4, "(Ropes.Trim does strip them)");
  r := Long("   leading blanks, then ", "a middle leaf of some length, ", "and trailing blanks    ");
  Check.Check(Is(Besm2Text.Trim(r), "leading blanks, then a middle leaf of some length, and trailing blanks"),
    "Trim across several leaves");

  Check.Check(Is(Besm2Text.Int(0), "0"), "Int of 0");
  Check.Check(Is(Besm2Text.Int(42), "42"), "Int of a positive number");
  Check.Check(Is(Besm2Text.Int(-7), "-7"), "Int of a negative number has an ASCII minus");
  Check.Check(Is(Besm2Text.Int(MAX(INTEGER)), "2147483647"), "Int of MAX(INTEGER)");
  Check.Check(Is(Besm2Text.Int(MIN(INTEGER)), "-2147483648"), "Int of MIN(INTEGER)");

  r := NIL;
  Besm2Text.Add(r, "a"); r := Ropes.AppendChar(r, "b"); r := Ropes.Cat(r, Ropes.Make(3, "-"));
  r := Ropes.Cat(r, Ropes.Make(0, "x")); r := Ropes.Cat(r, Ropes.Make(-2, "x")); Besm2Text.AddInt(r, 12);
  Check.Check(Is(r, "ab---12"), "Add, AppendChar, Make and AddInt build text");
  Besm2Text.Add(r, "");
  Check.Check(Is(r, "ab---12"), "Add of an empty string adds nothing");
  r := NIL; Besm2Text.Add(r, "");
  Check.Check(r = NIL, "Add of an empty string to an empty rope leaves it NIL");

  Besm2Text.Clear(l);
  Check.Check(Besm2Text.Join(l, ", ") = NIL, "Join of an empty list");
  Besm2Text.Append(l, R("one"));
  Check.Check(Is(Besm2Text.Join(l, ", "), "one"), "Join of one item");
  Besm2Text.Append(l, R("two")); Besm2Text.Append(l, R("three"));
  Check.Check(Is(Besm2Text.Join(l, ", "), "one, two, three"), "Join of three items");
  Besm2Text.Append(l, NIL); Besm2Text.Append(l, R("five"));
  Check.Check(Is(Besm2Text.Join(l, ", "), "one, two, three, , five"), "Join keeps an empty item's separators");

  Check.Check(Less("apple", "Banana"), "LessCI ignores case (a < B)");
  Check.Check(~Less("Banana", "apple"), "LessCI ignores case (not B < a)");
  Check.Check(~Less("Same", "sAME") & ~Less("sAME", "Same"), "LessCI: equal ignoring case");
  Check.Check(Less("Area", "Area Effect"), "LessCI: a proper prefix comes first");
  Check.Check(Less("", "a") & ~Less("a", "") & ~Less("", ""), "LessCI: the empty rope comes first");
  Check.Check(Less("Zebra", "Élan"), "LessCI: ASCII before a UTF-8 lead byte");
  (* The Ada To_Lower folding: "É" is C3 89, and C3 is folded to E3,
     past "“" (E2 80 9C), which isn't folded. *)
  Check.Check(Less("“quoted”", "Élan"), "LessCI folds UTF-8 lead byte C3 as Ada's To_Lower does");
  Check.Check(Ropes.CompareNoCase(R("“quoted”"), R("Élan")) > 0, "(Ropes.CompareNoCase doesn't)");
  Check.Check(Besm2Text.LessCI(Long("The Same Long Prefix, ", "continued in a second leaf, ", "ending in A"),
                               R("the same long prefix, continued in a second leaf, ending in b")),
    "LessCI across several leaves");

  Besm2Text.Clear(l);
  Besm2Text.Append(l, R("delta")); Besm2Text.Append(l, R("Charlie"));
  Besm2Text.Append(l, R("alpha")); Besm2Text.Append(l, R("Bravo"));
  Besm2Text.Append(l, R("ALPHA"));
  Besm2Text.SortCI(l);
  Check.Check(Is(Besm2Text.Join(l, ","), "alpha,ALPHA,Bravo,Charlie,delta"),
    "SortCI sorts ignoring case, keeping equal items in order");
  Check.Check(Is(l.items[0], "alpha") & Is(l.items[1], "ALPHA"), "SortCI keeps the items' own case");
  Besm2Text.Clear(l); Besm2Text.SortCI(l);
  Check.Check(l.n = 0, "SortCI of an empty list");
  Besm2Text.Clear(l);
  FOR i := 0 TO 15 DO y[0] := CHR(ORD("a") + i); y[1] := 0X; Besm2Text.Append(l, R(y)) END;
  Check.Check(l.n = 16, "List grows past its first allocation");
  Check.Check(Is(l.items[15], "p"), "List keeps items in order as it grows");

  s := Besm2Text.Chars(R("abc"));
  Check.Check((LEN(s^) = 4) & (s^ = "abc"), "Chars sizes the array to the text and its 0X");
  s := Besm2Text.Chars(NIL);
  Check.Check((s # NIL) & (LEN(s^) = 1) & (s[0] = 0X), "Chars of the empty rope is an empty string, not NIL");
  r := Long("a first leaf of some length, ", "a second leaf of some length, ", "and a third");
  s := Besm2Text.Chars(r);
  Check.Check(s^ = "a first leaf of some length, a second leaf of some length, and a third",
    "Chars across several leaves");

  Check.Summary
END TestText.
