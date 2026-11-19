// Live end-to-end check against the MNPR Supabase project, with a throwaway player that deletes itself.
// Needs a Supabase access token for api.supabase.com (saved as a network secret on the MNPR environment).
// Run: NODE_USE_ENV_PROXY=1 NODE_EXTRA_CA_CERTS=/root/.ccr/ca-bundle.crt node supabase/tests/live_test.mjs
const REF = "pkzkkawhfdbvqdzhymzy", URL = `https://${REF}.supabase.co`;
const keys = await (await fetch(`https://api.supabase.com/v1/projects/${REF}/api-keys?reveal=true`)).json();
const ANON = keys.find(k => k.name === "anon").api_key, SERVICE = keys.find(k => k.name === "service_role").api_key;
const ok = (c, what) => { if (!c) throw new Error("FAILED: " + what); console.log("ok:", what); };
const j = async r => { const t = await r.text(); try { return JSON.parse(t); } catch { return t; } };
const email = `mnpr-e2e-${Date.now()}@example.com`, password = crypto.randomUUID();
let uid;
try {
  const created = await j(await fetch(`${URL}/auth/v1/admin/users`, { method: "POST", headers: { apikey: SERVICE, Authorization: `Bearer ${SERVICE}`, "Content-Type": "application/json" }, body: JSON.stringify({ email, password, email_confirm: true }) }));
  uid = created.id; ok(uid, "test player created");
  const tok = (await j(await fetch(`${URL}/auth/v1/token?grant_type=password`, { method: "POST", headers: { apikey: ANON, "Content-Type": "application/json" }, body: JSON.stringify({ email, password }) }))).access_token;
  ok(tok, "test player signed in");
  const H = { apikey: ANON, Authorization: `Bearer ${tok}`, "Content-Type": "application/json" };
  const rpc = async (fn, body = {}, h = H) => fetch(`${URL}/rest/v1/rpc/${fn}`, { method: "POST", headers: h, body: JSON.stringify(body) });
  const me = async () => (await j(await fetch(`${URL}/rest/v1/profiles?id=eq.${uid}&select=n,username`, { headers: H })))[0];

  let r = await fetch(`${URL}/rest/v1/profiles`, { method: "POST", headers: H, body: JSON.stringify({ id: uid, username: "e2e_" + String(Date.now()).slice(-6) }) });
  ok(r.status === 201, "username saved");
  r = await rpc("log_sighting", { p_kind: "run", p_lat: 50.4712, p_lng: -4.7204, p_place: "Test" });
  ok(r.status === 200 && (await me()).n === 2, "unconfirmed run logged, number now 2");
  r = await fetch(`${URL}/rest/v1/profiles?id=eq.${uid}`, { method: "PATCH", headers: { ...H, Prefer: "return=representation" }, body: JSON.stringify({ n: 99 }) });
  ok(r.status >= 400 && (await me()).n === 2, "cannot set own number");

  const confirm = body => fetch(`${URL}/functions/v1/confirm-plate`, { method: "POST", headers: H, body: JSON.stringify(body) });
  r = await confirm({ kind: "run", plate: "AB17 CDE" });
  ok(r.status === 400 && /shows 17, not 2/.test((await j(r)).error), "wrong plate refused: " + "shows 17, not 2");
  r = await confirm({ kind: "run", plate: "ab02 cde", lat: 51.5, lng: -0.12 });
  const body = await j(r);
  ok(r.status === 200 && body.checkedBy === "format" && (await me()).n === 3, "confirmed run via plate checker (format check), number now 3");
  r = await confirm({ kind: "spot", n: 2, plate: "AB02CDE" });
  ok(r.status === 400 && /already logged/.test((await j(r)).error), "same plate can't earn XP twice");
  r = await fetch(`${URL}/functions/v1/confirm-plate`, { method: "POST", headers: { apikey: ANON, "Content-Type": "application/json" }, body: JSON.stringify({ kind: "run", plate: "AB03CDE" }) });
  ok(r.status === 401, "plate checker refuses signed-out callers");

  const rows = await j(await fetch(`${URL}/rest/v1/sightings?select=n,kind,checked_by,plate_hash`, { headers: H }));
  ok(rows.length === 2 && rows.every(x => !JSON.stringify(x).includes("AB02")), "2 sightings stored, plate not stored");
  const AH = { apikey: ANON, Authorization: `Bearer ${ANON}`, "Content-Type": "application/json" };
  const heat = await j(await rpc("heat", {}, AH));
  ok(Array.isArray(heat) && heat.some(h => h.lat === 50.47), "visitors see the map, rounded");
  ok((await j(await rpc("leaderboard", {}, AH))).length >= 1, "visitors see the leaderboard");
  const peek = await fetch(`${URL}/rest/v1/sightings?select=*`, { headers: AH });
  const seen = await j(peek);
  console.log("   visitor read:", peek.status, JSON.stringify(seen).slice(0, 120));
  ok(peek.status >= 400 || (Array.isArray(seen) && seen.length === 0), "visitors cannot read sightings");

  r = await rpc("delete_account");
  ok(r.status === 204 || r.status === 200, "player deleted their account");
  const gone = await fetch(`${URL}/auth/v1/admin/users/${uid}`, { headers: { apikey: SERVICE, Authorization: `Bearer ${SERVICE}` } });
  ok(gone.status === 404, "account really gone");
  uid = null;
  console.log("ALL LIVE CHECKS PASSED");
} finally {
  if (uid) await fetch(`${URL}/auth/v1/admin/users/${uid}`, { method: "DELETE", headers: { apikey: SERVICE, Authorization: `Bearer ${SERVICE}` } }), console.log("cleaned up test player");
}
