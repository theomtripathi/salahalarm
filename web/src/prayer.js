// Prayer times for the visitor's approximate location (Cloudflare IP geolocation),
// so the plan screen can show a real first alarm without asking for location.
// The Android app uses the same country → method table (PrayerMethods.kt).

import { Coordinates, CalculationMethod, PrayerTimes, Madhab } from "adhan";

const METHOD_BY_COUNTRY = {
  SA: "UmmAlQura", YE: "UmmAlQura",
  AE: "Dubai", OM: "Dubai", BH: "Dubai",
  QA: "Qatar", KW: "Kuwait",
  EG: "Egyptian", SD: "Egyptian", LY: "Egyptian", SY: "Egyptian", LB: "Egyptian", JO: "Egyptian", PS: "Egyptian", IQ: "Egyptian",
  TR: "Turkey", AZ: "Turkey",
  IR: "Tehran",
  PK: "Karachi", IN: "Karachi", BD: "Karachi", AF: "Karachi", LK: "Karachi", NP: "Karachi",
  SG: "Singapore", MY: "Singapore", ID: "Singapore", BN: "Singapore",
  US: "NorthAmerica", CA: "NorthAmerica",
  GB: "MoonsightingCommittee", IE: "MoonsightingCommittee",
};

// Hanafi Asr is the norm in South Asia, Turkey and Central Asia.
const HANAFI = new Set(["PK", "IN", "BD", "AF", "TR", "UZ", "TJ", "KG", "TM", "KZ"]);

export const PRAYERS = ["fajr", "dhuhr", "asr", "maghrib", "isha"];

export function methodFor(country) {
  return METHOD_BY_COUNTRY[String(country || "").toUpperCase()] || "MuslimWorldLeague";
}

export function madhabFor(country) {
  return HANAFI.has(String(country || "").toUpperCase()) ? "hanafi" : "shafi";
}

export function prayerTimes({ latitude, longitude, country, date = new Date() }) {
  const lat = Number(latitude);
  const lon = Number(longitude);
  if (!Number.isFinite(lat) || !Number.isFinite(lon)) return null;
  const method = methodFor(country);
  const params = CalculationMethod[method]();
  params.madhab = madhabFor(country) === "hanafi" ? Madhab.Hanafi : Madhab.Shafi;
  const pt = new PrayerTimes(new Coordinates(lat, lon), date, params);
  const times = Object.fromEntries(PRAYERS.map((p) => [p, pt[p].toISOString()]));
  return { method, madhab: madhabFor(country), times };
}

/** Today's and tomorrow's times, plus the next prayer that can still ring. */
export function scheduleFor({ latitude, longitude, country, timezone, now = new Date() }) {
  // Calculate by the visitor's local calendar date, not the server's.
  const localDate = (offsetDays) => {
    const parts = new Intl.DateTimeFormat("en-CA", { timeZone: timezone || "UTC", year: "numeric", month: "2-digit", day: "2-digit" })
      .format(new Date(now.getTime() + offsetDays * 86400000))
      .split("-")
      .map(Number);
    return new Date(parts[0], parts[1] - 1, parts[2], 12);
  };
  const today = prayerTimes({ latitude, longitude, country, date: localDate(0) });
  if (!today) return null;
  const tomorrow = prayerTimes({ latitude, longitude, country, date: localDate(1) });
  return { ...today, tomorrow: tomorrow.times };
}
