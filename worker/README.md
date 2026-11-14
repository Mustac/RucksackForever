# The report relay

The website's report form sends reports here, and this files each one as an issue with the label
`feedback` in the repository. That's what lets anyone report without a GitHub account.

## Set it up once

1. **GitHub token.** GitHub > Settings > Developer settings > Fine-grained tokens > Generate new token.
   Repository access: only `RucksackForever`. Permissions: Issues = Read and write. Nothing else.
   Copy the token; you'll paste it in step 3.
2. **Cloudflare Worker.** Sign in at dash.cloudflare.com > Workers & Pages > Create > Worker.
   Name it `rucksack-report`, deploy the starter, then Edit code: replace everything with
   `worker.js` from this folder and Deploy.
3. **Its settings.** In the worker: Settings > Variables and Secrets.
   - Secret `GITHUB_TOKEN`: the token from step 1.
   - Text `REPO`: `Mustac/RucksackForever`
   - Text `ORIGIN`: `https://mustac.github.io`
4. **Tell the website.** Put the worker's address (like `https://rucksack-report.NAME.workers.dev`)
   in `docs/config.js` as `relay`, and push.

## Limits

Five reports an hour per address (a brake kept in memory, so not exact), a hidden field that only
bots fill in, and length limits. Reports are public issues.
