// UK number plate rules, shared by the app (build.py inlines this file) and the confirm-plate edge function.
// Plates are checked with spaces removed and letters capitalised.
const PLATE_FORMATS = [
  /^[A-Z]{2}[0-9]{2}[A-Z]{3}$/, // current, from 2001: AB12 CDE
  /^[A-Z][0-9]{1,3}[A-Z]{3}$/,  // prefix, 1983 to 2001: A123 BCD
  /^[A-Z]{3}[0-9]{1,3}[A-Z]$/,  // suffix, 1963 to 1983: ABC 123D
  /^[A-Z]{1,3}[0-9]{1,4}$/,     // dateless and Northern Ireland: ABC 1234
  /^[0-9]{1,4}[A-Z]{1,3}$/      // dateless, numbers first: 1234 AB
];

export function normalisePlate(text) {
  return String(text || "").toUpperCase().replace(/[^A-Z0-9]/g, "");
}

// The number a plate shows: its digits with leading zeros dropped, or null if it has none.
export function plateNumber(text) {
  const digits = normalisePlate(text).replace(/[^0-9]/g, "").replace(/^0+/, "");
  return digits ? Number(digits) : null;
}

// Whether a plate can count for number n. Returns { ok, reason }.
export function checkPlate(text, n) {
  const plate = normalisePlate(text);
  if (!PLATE_FORMATS.some(f => f.test(plate))) return { ok: false, reason: "That isn't a UK plate." };
  const shows = plateNumber(plate);
  if (shows !== n) return { ok: false, reason: shows === null ? "That plate has no number." : `That plate shows ${shows}, not ${n}.` };
  return { ok: true };
}
