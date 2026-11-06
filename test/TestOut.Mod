MODULE TestOut; (* Unit tests for Besm2Out's ToRope and TakeRope *)

IMPORT Check, Besm2Out, Ropes;

CONST BufSize = 8192;  (* Besm2Out's buffer *)

PROCEDURE TestRope;
  VAR r: Ropes.Rope; i: LONGINT; ok: BOOLEAN;
BEGIN
  Besm2Out.ToRope;
  r := Besm2Out.TakeRope();
  Check.Check(r = NIL, "nothing written: NIL");

  Besm2Out.ToRope;
  Besm2Out.String("abc"); Besm2Out.Ln; Besm2Out.Rope(Ropes.FromString("de")); Besm2Out.Repeat("f", 3);
  r := Besm2Out.TakeRope();
  Check.Check(Ropes.Equal(r, Ropes.Cat(Ropes.AppendChar(Ropes.FromString("abc"), 0AX), Ropes.FromString("defff"))),
    "what was written, in order");

  (* More than the buffer holds, so it is flushed into the rope midway. *)
  Besm2Out.ToRope;
  Besm2Out.Repeat("x", 2 * BufSize + 5); Besm2Out.Char("y");
  r := Besm2Out.TakeRope();
  ok := Ropes.Length(r) = 2 * BufSize + 6;
  FOR i := 0 TO 2 * BufSize + 4 DO ok := ok & (Ropes.Fetch(r, i) = "x") END;
  Check.Check(ok & (Ropes.Fetch(r, 2 * BufSize + 5) = "y"), "past the buffer: all of it, in order");

  Besm2Out.ToRope;
  r := Besm2Out.TakeRope();
  Check.Check(r = NIL, "taken: kept from scratch the next time");
  Check.Check(Besm2Out.Close() = 0, "no write errors")
END TestRope;

BEGIN
  TestRope;
  Check.Summary
END TestOut.
