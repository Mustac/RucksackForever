# The report relay

The website's report form sends reports here, and this saves each one as an issue in the private
`rucksack-feedback` repository, where only the developer can read it. The panel (`docs/panel.html`) reads them
through the relay with a passphrase. That's what lets anyone report without a GitHub account.

## Set it up once

1. **GitHub token.** GitHub > Settings > Developer settings > Fine-grained tokens > Generate new token.
   Repository access: only the private `rucksack-feedback`. Permissions: Issues = Read and write. Nothing else.
   Copy the token; you'll paste it in step 3.
2. **Cloudflare Worker.** Sign in at dash.cloudflare.com > Workers & Pages > Create > Worker.
   Name it `rucksack-report`, deploy the starter, then Edit code: replace everything with
   `worker.js` from this folder and Deploy.
3. **Its settings.** In the worker: Settings > Variables and Secrets.
   - Secret `GITHUB_TOKEN`: the token from step 1.
   - Secret `ADMIN_KEY`: the passphrase for the panel (long, used nowhere else).
   - Text `REPO`: `Mustac/rucksack-feedback`
   - Text `ORIGIN`: `https://mustac.github.io`
4. **Tell the website.** Put the worker's address (like `https://rucksack-report.NAME.workers.dev`)
   in `docs/config.js` as `relay`, and push.

## Limits

Five reports an hour per address (a brake kept in memory, so not exact), a hidden field that only
bots fill in, length limits, and ten wrong passphrases an hour per address. Reports are private.
