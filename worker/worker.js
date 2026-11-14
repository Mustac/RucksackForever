// Rucksack report relay (a Cloudflare Worker). The report form on the website posts here; this files
// the report as an issue (label "feedback") in the repository, so nobody needs a GitHub account.
// Secrets (set in Cloudflare, never in this file): GITHUB_TOKEN = a token that can only write issues
// in this one repository. Plain variables: REPO ("Mustac/RucksackForever"), ORIGIN (the website).
const PER_HOUR = 5;          // reports one address may send in an hour
const seen = new Map();      // address -> times (kept while this worker instance lives: a brake, not a wall)

function reply(body, status, origin) {
  return new Response(JSON.stringify(body), { status, headers: {
    "Content-Type": "application/json", "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Methods": "POST, OPTIONS", "Access-Control-Allow-Headers": "Content-Type", "Vary": "Origin" } });
}
function clean(v, max) { return (typeof v === "string" ? v : "").replace(/\u0000/g, "").trim().slice(0, max); }

export default {
  async fetch(request, env) {
    const origin = env.ORIGIN || "https://mustac.github.io";
    if (request.method === "OPTIONS") return reply({}, 200, origin);
    if (request.method !== "POST") return reply({ error: "Send reports from the report page." }, 405, origin);
    if ((request.headers.get("Origin") || "") !== origin) return reply({ error: "Send reports from the report page." }, 403, origin);
    let data;
    try { data = await request.json(); } catch (e) { return reply({ error: "That report couldn't be read." }, 400, origin); }
    // (a field people never see: only bots fill it in. They get a "thanks" and nothing is filed)
    if (clean(data.website, 200) !== "") return reply({ ok: true }, 200, origin);
    const what = clean(data.what, 4000), report = clean(data.report, 8000), name = clean(data.name, 60);
    if (what.length < 10) return reply({ error: "Write a few words about what happened first." }, 400, origin);
    const ip = request.headers.get("CF-Connecting-IP") || "?";
    const now = Date.now();
    const times = (seen.get(ip) || []).filter((t) => now - t < 3600000);
    if (times.length >= PER_HOUR) return reply({ error: "That's a lot of reports in one hour. Try again later." }, 429, origin);
    times.push(now);
    seen.set(ip, times);
    const title = what.split("\n")[0].slice(0, 80);
    const body = "**What happened**\n\n" + what + "\n\n**Report from the game**\n\n```\n" + (report || "(none)").replace(/```/g, "'''") + "\n```\n\n" +
      "Sent from the website" + (name ? " by " + name.replace(/[@#\[\]<>]/g, "") : "") + ".";
    const res = await fetch("https://api.github.com/repos/" + (env.REPO || "Mustac/RucksackForever") + "/issues", {
      method: "POST",
      headers: { "Authorization": "Bearer " + env.GITHUB_TOKEN, "Accept": "application/vnd.github+json", "User-Agent": "rucksack-report-relay", "Content-Type": "application/json" },
      body: JSON.stringify({ title, body, labels: ["feedback"] }) });
    if (!res.ok) return reply({ error: "The report couldn't be saved just now. Try again in a moment." }, 502, origin);
    return reply({ ok: true }, 200, origin);
  }
};
