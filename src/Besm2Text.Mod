MODULE Besm2Text; (* What this program needs of text that Ropes doesn't have *)

(* Every string in this program is a Ropes.Rope, and callers use Ropes
   directly for whatever it provides.  This module adds only what it
   lacks: decimal integers, the width of UTF-8 text in characters, the
   Ada version's trimming and case folding (Ropes' own differ from them:
   see Trim and FoldCI), a growable list of ropes with Join and a stable
   sort, and a flat copy for the few procedures that take an ARRAY OF
   CHAR.  It replaces the Buffer port's Besm2Str, which had its own
   string and buffer types (PLAN.md, section 1).

   The empty rope is NIL, so "" and "absent" can't be told apart by the
   rope alone.  Lengths are in bytes; DisplayLength counts UTF-8
   characters.

   Independent of Fyaml, like the Ada Text_Layout, so it can be tested
   without YAML. *)

IMPORT Ropes;

TYPE
  Rope* = Ropes.Rope;

  (* A flat, 0X-terminated copy of a rope: see Chars. *)
  String* = POINTER TO ARRAY OF CHAR;

  Items* = POINTER TO ARRAY OF Rope;

  (* A growable list of ropes: items[0 .. n-1], any of which may be NIL
     (the empty rope).  Clear a List before its first use: a local one
     is not initialized. *)
  List* = RECORD
    items-: Items;
    n-: INTEGER
  END;

VAR
  (* The characters Trim strips, and every byte that starts a UTF-8
     character (all but the continuation bytes 80X..0BFX). *)
  blanks, leads: Ropes.CharSet;

(* ---- Building ---- *)

(* Appends the text of s, up to its first 0X, to r.  r must have been
   set before (to NIL, for a rope being built up).  poc zeroes local
   variables, but voc, which this was written for, doesn't. *)
PROCEDURE Add*(VAR r: Rope; s: ARRAY OF CHAR);
BEGIN r := Ropes.Cat(r, Ropes.FromString(s))
END Add;

(* i in decimal, with a leading "-" if negative and no blanks, as the
   Ada version's Trim (Integer'Image (i), Left). *)
PROCEDURE Int*(i: INTEGER): Rope;
  VAR digits: ARRAY 12 OF CHAR; n: INTEGER; u: LONGINT;
BEGIN
  (* INTEGER is 32 bits and LONGINT 64 under -OC, so -u can't overflow
     even for MIN(INTEGER), and DIV and MOD only see non-negative
     values (voc's DIV misbehaves near MIN(LONGINT): olibfyaml's
     AGENTS.md; kept for poc).  The digits are written from the end of the array:
     11 at most, with the sign. *)
  u := i;
  IF u < 0 THEN u := -u END;
  n := LEN(digits);
  REPEAT
    DEC(n); digits[n] := CHR(ORD("0") + SHORT(u MOD 10)); u := u DIV 10
  UNTIL u = 0;
  IF i < 0 THEN DEC(n); digits[n] := "-" END;
  RETURN Ropes.FromSubstring(digits, n, LEN(digits) - n)
END Int;

(* Appends i, as Int writes it, to r. *)
PROCEDURE AddInt*(VAR r: Rope; i: INTEGER);
BEGIN r := Ropes.Cat(r, Int(i))
END AddInt;

(* ---- Measuring and trimming ---- *)

(* The number of characters in r, UTF-8 text -- not its length in
   bytes, which is Ropes.Length.  Counts every byte that isn't a UTF-8
   continuation byte (80X..0BFX); doesn't check that r is well-formed
   UTF-8.  The column widths of the grid tables are measured with this,
   as besm2-rst.scm's are with Chicken's character-counting
   string-length; with a byte count, a column holding a curly quote
   or a "×" would come out narrow and the table borders wouldn't line
   up. *)
PROCEDURE DisplayLength*(r: Rope): LONGINT;
BEGIN RETURN Ropes.CountSet(r, leads)
END DisplayLength;

(* r without leading and trailing blanks, tabs, line feeds and carriage
   returns.  All four, not just blanks: a YAML literal block scalar
   ("details: |") ends with a newline, which besm2-rst.scm's
   string-trim-both removes, and which would otherwise end up in the
   middle of a sentence in the output (a bug the Ada port hit with
   Ada.Strings.Fixed.Trim, which strips only blanks).  Not Ropes.Trim,
   which strips form feeds too; the Ada version keeps them. *)
PROCEDURE Trim*(r: Rope): Rope;
  VAR first, last: LONGINT;
BEGIN
  first := Ropes.IndexSet(r, blanks, FALSE, 0);
  IF first < 0 THEN RETURN NIL END;
  last := Ropes.RIndexSet(r, blanks, FALSE, Ropes.Length(r) - 1);
  IF (first = 0) & (last = Ropes.Length(r) - 1) THEN RETURN r END;
  RETURN Ropes.Substring(r, first, last - first + 1)
END Trim;

(* ---- Case-insensitive order ---- *)

(* Ada.Characters.Handling.To_Lower, which the Ada version sorts with:
   it lowers A..Z and also the Latin-1 capitals C0X..DEX except D7X.
   In UTF-8 those are lead bytes, so this doesn't lower non-ASCII
   letters, but it does move names starting with some of them (C3X,
   for example, becomes E3X) relative to others.  Copied as is so that
   names sort as they do in the Ada version (the Buffer port's PLAN.md,
   open questions).  Ropes.LowerChar, and so Ropes.CompareNoCase, fold
   A..Z only. *)
PROCEDURE Lower(c: CHAR): CHAR;
BEGIN
  IF ((c >= "A") & (c <= "Z")) OR ((c >= 0C0X) & (c <= 0DEX) & (c # 0D7X)) THEN
    RETURN CHR(ORD(c) + 32)
  END;
  RETURN c
END Lower;

(* r with every byte lowered as the Ada version lowers it: the key
   names are sorted by. *)
PROCEDURE FoldCI*(r: Rope): Rope;
BEGIN RETURN Ropes.Map(r, Lower)
END FoldCI;

(* TRUE if a comes before b ignoring case, as the Ada version's CI_Less:
   both lowered, then compared byte by byte, a proper prefix first.
   To sort, fold each name once with FoldCI and compare the keys with
   Ropes.Compare instead, as SortCI does. *)
PROCEDURE LessCI*(a, b: Rope): BOOLEAN;
  VAR ka, kb: Rope;
BEGIN
  ka := FoldCI(a); kb := FoldCI(b);
  RETURN Ropes.Compare(ka, kb) < 0
END LessCI;

(* ---- List ---- *)

PROCEDURE Clear*(VAR l: List);
BEGIN l.items := NIL; l.n := 0
END Clear;

PROCEDURE Append*(VAR l: List; r: Rope);
  VAR t: Items; i: INTEGER;
BEGIN
  IF l.items = NIL THEN NEW(l.items, 8); l.n := 0
  ELSIF l.n = LEN(l.items^) THEN
    NEW(t, 2 * l.n);
    FOR i := 0 TO l.n - 1 DO t[i] := l.items[i] END;
    l.items := t
  END;
  l.items[l.n] := r; INC(l.n)
END Append;

(* The items joined with sep between them; NIL (empty) for an empty
   list. *)
PROCEDURE Join*(l: List; sep: ARRAY OF CHAR): Rope;
  VAR r, s: Rope; i: INTEGER;
BEGIN
  r := NIL; s := Ropes.FromString(sep);
  FOR i := 0 TO l.n - 1 DO
    IF i > 0 THEN r := Ropes.Cat(r, s) END;
    r := Ropes.Cat(r, l.items[i])
  END;
  RETURN r
END Join;

(* Sorts l by LessCI.  An insertion sort: stable, and the lists here
   are a handful of items.  Each item is folded once, into keys. *)
PROCEDURE SortCI*(VAR l: List);
  VAR i, j: INTEGER; r, k: Rope; keys: Items;
BEGIN
  IF l.n < 2 THEN RETURN END;
  NEW(keys, l.n);
  FOR i := 0 TO l.n - 1 DO keys[i] := FoldCI(l.items[i]) END;
  FOR i := 1 TO l.n - 1 DO
    r := l.items[i]; k := keys[i]; j := i;
    WHILE (j > 0) & (Ropes.Compare(k, keys[j - 1]) < 0) DO
      l.items[j] := l.items[j - 1]; keys[j] := keys[j - 1]; DEC(j)
    END;
    l.items[j] := r; keys[j] := k
  END
END SortCI;

(* ---- Flat copies ---- *)

(* The text of r as a 0X-terminated array of exactly Length(r) + 1
   characters, for the procedures that take an ARRAY OF CHAR: Err.String,
   Platform's and polibfyaml's file names.  Never NIL.  Output goes
   through Besm2Out.Rope instead, which doesn't copy. *)
PROCEDURE Chars*(r: Rope): String;
  VAR s: String;
BEGIN
  NEW(s, Ropes.Length(r) + 1);
  Ropes.ToString(r, s^);
  RETURN s
END Chars;

PROCEDURE Init;
  VAR i: INTEGER;
BEGIN
  Ropes.MakeCharSet(" ", blanks);
  blanks.has[09H] := TRUE; blanks.has[0AH] := TRUE; blanks.has[0DH] := TRUE;
  FOR i := 0 TO 255 DO leads.has[i] := (i < 80H) OR (i > 0BFH) END
END Init;

BEGIN
  Init
END Besm2Text.
