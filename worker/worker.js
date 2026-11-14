// Rucksack report relay (a Cloudflare Worker).
//  * The report form on the website posts here; each report is saved as an issue in a PRIVATE
//    repository, so only the developer can read it and nobody needs a GitHub account to send one.
//  * The developer's panel on the website reads and closes reports through here, with a passphrase.
// Secrets (set in Cloudflare, never in this file):
//   GITHUB_TOKEN  a token that can only read and write issues in the private feedback repository
//   ADMIN_KEY     the passphrase for the panel
// The repository is fixed below on purpose: reports must never land in a public one by a wrong setting.
const REPO = "Mustac/rucksack-feedback";
const ORIGIN = "https://mustac.github.io";
const PER_HOUR = 5;           // reports one address may send in an hour
const WRONG_PER_HOUR = 10;    // wrong passphrases one address may try in an hour
const sent = new Map(), wrong = new Map(); // (kept while this worker instance lives: a brake, not a wall)

function reply(body, status, origin) {
  return new Response(JSON.stringify(body), { status, headers: {
    "Content-Type": "application/json", "Cache-Control": "no-store", "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS", "Access-Control-Allow-Headers": "Content-Type, X-Key", "Vary": "Origin" } });
}
function clean(v, max) { return (typeof v === "string" ? v : "").replace(/\u0000/g, "").trim().slice(0, max); }
function recent(map, ip) { const now = Date.now(); const t = (map.get(ip) || []).filter((x) => now - x < 3600000); map.set(ip, t); return t; }
function same(a, b) { // (compares every character, so a wrong guess learns nothing from timing)
  if (typeof a !== "string" || typeof b !== "string" || a.length !== b.length) return false;
  let d = 0;
  for (let i = 0; i < a.length; i++) d |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return d === 0;
}
function github(env, path, init) {
  return fetch("https://api.github.com/repos/" + REPO + path, Object.assign({}, init, { headers: {
    "Authorization": "Bearer " + env.GITHUB_TOKEN, "Accept": "application/vnd.github+json",
    "User-Agent": "rucksack-report-relay", "Content-Type": "application/json" } }));
}

export default {
  async fetch(request, env) {
    const origin = ORIGIN;
    if (request.method === "OPTIONS") return reply({}, 200, origin);
    if ((request.headers.get("Origin") || "") !== origin) return reply({ error: "Send reports from the report page." }, 403, origin);
    if (!env.GITHUB_TOKEN) return reply({ error: "The report service isn't set up yet." }, 503, origin);
    const url = new URL(request.url);
    const ip = request.headers.get("CF-Connecting-IP") || "?";

    // ---- the developer's panel: needs the passphrase
    if (url.pathname === "/list" || url.pathname === "/state") {
      const tries = recent(wrong, ip);
      if (tries.length >= WRONG_PER_HOUR) return reply({ error: "Too many wrong passphrases. Try again in an hour." }, 429, origin);
      if (!env.ADMIN_KEY || !same(request.headers.get("X-Key") || "", env.ADMIN_KEY)) {
        tries.push(Date.now());
        return reply({ error: "Wrong passphrase." }, 401, origin);
      }
      if (url.pathname === "/list" && request.method === "GET") {
        const out = [];
        for (let page = 1; page <= 3; page++) {
          const res = await github(env, "/issues?state=all&per_page=100&sort=created&direction=desc&page=" + page);
          if (!res.ok) return reply({ error: "Couldn't read the reports (GitHub said " + res.status + ")." }, 502, origin);
          const list = await res.json();
          for (const i of list) {
            if (!i.pull_request) out.push({ number: i.number, title: i.title, body: i.body || "", state: i.state, created_at: i.created_at, closed_at: i.closed_at });
          }
          if (list.length < 100) break;
        }
        return reply({ ok: true, reports: out }, 200, origin);
      }
      if (url.pathname === "/state" && request.method === "POST") {
        let d;
        try { d = await request.json(); } catch (e) { return reply({ error: "That couldn't be read." }, 400, origin); }
        const n = parseInt(d.number, 10);
        if (!n || (d.state !== "open" && d.state !== "closed")) return reply({ error: "That couldn't be read." }, 400, origin);
        const res = await github(env, "/issues/" + n, { method: "PATCH", body: JSON.stringify({ state: d.state }) });
        if (!res.ok) return reply({ error: "Couldn't change it (GitHub said " + res.status + ")." }, 502, origin);
        return reply({ ok: true }, 200, origin);
      }
      return reply({ error: "Not found." }, 404, origin);
    }

    // ---- a report from the form
    if (request.method !== "POST") return reply({ error: "Send reports from the report page." }, 405, origin);
    let data;
    try { data = await request.json(); } catch (e) { return reply({ error: "That report couldn't be read." }, 400, origin); }
    // (a field people never see: only bots fill it in. They get a "thanks" and nothing is saved)
    if (clean(data.website, 200) !== "") return reply({ ok: true }, 200, origin);
    const what = clean(data.what, 4000), report = clean(data.report, 8000), name = clean(data.name, 60);
    const kind = data.kind === "idea" ? "idea" : "bug";
    if (what.length < 10) return reply({ error: "Write a few words about what happened first." }, 400, origin);
    const times = recent(sent, ip);
    if (times.length >= PER_HOUR) return reply({ error: "That's a lot of reports in one hour. Try again later." }, 429, origin);
    times.push(Date.now());
    const title = "[" + kind + "] " + what.split("\n")[0].slice(0, 80);
    const body = "**What happened**\n\n" + what + "\n\n**Report from the game**\n\n```\n" + (report || "(none)").replace(/```/g, "'''") + "\n```\n\n" +
      "Sent from the website" + (name ? " by " + name.replace(/[@#\[\]<>]/g, "") : "") + ".";
    const res = await github(env, "/issues", { method: "POST", body: JSON.stringify({ title, body }) });
    if (!res.ok) return reply({ error: "The report couldn't be saved just now. Try again in a moment." }, 502, origin);
    return reply({ ok: true }, 200, origin);
  }
};
