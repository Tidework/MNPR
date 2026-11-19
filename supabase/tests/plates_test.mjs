// Checks the UK plate rules. Run: node supabase/tests/plates_test.mjs
import { checkPlate } from "../functions/confirm-plate/plates.js";
const cases = [["AB01 CDE",1,true],["ab07cde",7,true],["AB17 CDE",7,false],["A1 ABC",1,true],["A1ABC",2,false],["A123 BCD",123,true],["ABC 123D",123,true],
["ABC 1234",1234,true],["1234 AB",1234,true],["KX70 ABC",70,true],["XYZ",1,false],["AB12 CDE",21,false],["H 1",1,true],["007 X",7,true],["AB00 CDE",0,false],["ABCD123",123,false]];
let bad = 0;
for (const [p, n, want] of cases) { const r = checkPlate(p, n); if (r.ok !== want) { bad++; console.log("WRONG", p, n, r); } }
console.log(bad ? bad + " wrong" : "all " + cases.length + " plate cases right");
if (bad) process.exit(1);
