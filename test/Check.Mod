MODULE Check; (* Shared ok/FAIL reporting for the test programs *)

(* Each test program calls Check once per check and Summary at the
   very end of its body. Output, per check:
     ok   - <label>
     FAIL - <label>
   then "All checks passed." or "<N> check(s) failed."

   Summary exits with status 1 only when something failed. A passing
   run returns normally, so the main module's end runs every pending GC
   finalizer. (Under voc, Platform.Exit skipped them, which made
   valgrind's leak report on a passing run meaningless; poc runs them
   at Platform.Exit too, but returning normally is kept.) *)

IMPORT Out, Platform;

VAR failed: LONGINT;

PROCEDURE Check*(ok: BOOLEAN; label: ARRAY OF CHAR);
BEGIN
  IF ok THEN Out.String("ok   - ") ELSE Out.String("FAIL - "); INC(failed) END;
  Out.String(label); Out.Ln
END Check;

PROCEDURE Summary*;
BEGIN
  IF failed = 0 THEN
    Out.String("All checks passed."); Out.Ln
  ELSE
    Out.Int(failed, 0); Out.String(" check(s) failed."); Out.Ln;
    Platform.Exit(1)
  END
END Summary;

BEGIN failed := 0
END Check.
