// Confirms a sighting from a full number plate, then records it with full XP.
//
// 1. Checks the plate is a UK format showing the right number (plates.js).
// 2. If a DVLA_API_KEY secret is set, asks the DVLA Vehicle Enquiry Service that a vehicle has
//    that plate. If DVLA is busy or down, the format check stands.
// 3. Records the sighting through log_confirmed. The plate itself is never stored, only a keyed
//    hash (PLATE_PEPPER secret) so the same plate can't earn the same player XP twice.
import { createClient } from "jsr:@supabase/supabase-js@2";
import { checkPlate, normalisePlate } from "./plates.js";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const reply = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });

async function keyedHash(secret: string, text: string) {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(text));
  return [...new Uint8Array(sig)].map(b => b.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async req => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return reply(405, { error: "Use POST." });
  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const asUser = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
    });
    const { data: { user } } = await asUser.auth.getUser();
    if (!user) return reply(401, { error: "Sign in to confirm a plate." });

    const body = await req.json().catch(() => ({}));
    const kind = body.kind === "spot" ? "spot" : "run";
    const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

    let n = Number(body.n);
    if (kind === "run") {
      const { data } = await admin.from("profiles").select("n").eq("id", user.id).single();
      if (!data) return reply(400, { error: "Choose a username first." });
      n = data.n;
    }
    if (!Number.isInteger(n) || n < 1) return reply(400, { error: "Enter the number you saw." });

    const plate = normalisePlate(body.plate);
    const check = checkPlate(plate, n);
    if (!check.ok) return reply(400, { error: check.reason });

    let checkedBy = "format";
    let vehicle: { make?: string; colour?: string } | null = null;
    const dvlaKey = Deno.env.get("DVLA_API_KEY");
    if (dvlaKey) {
      const res = await fetch("https://driver-vehicle-licensing.api.gov.uk/vehicle-enquiry/v1/vehicles", {
        method: "POST",
        headers: { "x-api-key": dvlaKey, "Content-Type": "application/json" },
        body: JSON.stringify({ registrationNumber: plate }),
      }).catch(() => null);
      if (res && (res.status === 404 || res.status === 400)) return reply(400, { error: "DVLA has no vehicle with that plate." });
      if (res && res.ok) {
        const v = await res.json();
        checkedBy = "dvla";
        vehicle = { make: v.make, colour: v.colour };
      }
    }

    const pepper = Deno.env.get("PLATE_PEPPER") ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const { data: sighting, error } = await admin.rpc("log_confirmed", {
      p_user: user.id, p_kind: kind, p_n: n,
      p_plate_hash: await keyedHash(pepper, `${user.id}:${plate}`), p_checked_by: checkedBy,
      p_lat: body.lat ?? null, p_lng: body.lng ?? null, p_place: body.place ?? null,
    });
    if (error) return reply(400, { error: error.message });
    return reply(200, { sighting, checkedBy, vehicle });
  } catch (_e) {
    return reply(500, { error: "Couldn't check that plate. Try again." });
  }
});
