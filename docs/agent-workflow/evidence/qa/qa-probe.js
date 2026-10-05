// Read-only QA probe: visits pages, records console errors / failed requests / DOM facts, saves screenshots.
const { chromium } = require('playwright');
const fs = require('fs');
const OUT = '/Users/opsai/Taipei-City-Dashboard/docs/agent-workflow/evidence/qa';
fs.mkdirSync(OUT, { recursive: true });

const pages = [
  { name: 'dashboard', url: 'http://localhost:8080/dashboard', wait: 6000 },
  { name: 'mapview', url: 'http://localhost:8080/mapview', wait: 12000 },
  { name: 'admin', url: 'http://localhost:8080/admin', wait: 4000 },
];

(async () => {
  const browser = await chromium.launch({ headless: true });
  const results = [];
  for (const p of pages) {
    const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 } });
    const page = await ctx.newPage();
    const consoleErrors = [], failed = [], badResponses = [];
    page.on('console', m => { if (['error', 'warning'].includes(m.type())) consoleErrors.push(`[${m.type()}] ${m.text().slice(0, 300)}`); });
    page.on('pageerror', e => consoleErrors.push(`[pageerror] ${String(e).slice(0, 300)}`));
    page.on('requestfailed', r => failed.push(`${r.method()} ${r.url().slice(0, 160)} :: ${r.failure() && r.failure().errorText}`));
    page.on('response', r => { if (r.status() >= 400) badResponses.push(`${r.status()} ${r.url().slice(0, 160)}`); });
    let nav = 'ok';
    try { await page.goto(p.url, { waitUntil: 'domcontentloaded', timeout: 30000 }); } catch (e) { nav = 'nav-error: ' + String(e).slice(0, 200); }
    await page.waitForTimeout(p.wait);
    const facts = await page.evaluate(() => ({
      title: document.title,
      path: location.pathname,
      textLen: document.body.innerText.length,
      canvas: document.querySelectorAll('canvas').length,
      mapboxCanvas: document.querySelectorAll('.mapboxgl-canvas').length,
      charts: document.querySelectorAll('.apexcharts-canvas, [class*="chart"]').length,
      headings: Array.from(document.querySelectorAll('h1,h2,h3,h4')).slice(0, 8).map(h => h.innerText.trim().slice(0, 40)),
      inputs: Array.from(document.querySelectorAll('input')).map(i => i.type + ':' + (i.placeholder || i.name || '')).slice(0, 6),
      bodySample: document.body.innerText.replace(/\s+/g, ' ').slice(0, 220),
    })).catch(e => ({ evalError: String(e).slice(0, 200) }));
    await page.screenshot({ path: `${OUT}/${p.name}.png`, fullPage: false });
    results.push({ page: p.name, url: p.url, nav, facts, consoleErrors: consoleErrors.slice(0, 15), consoleErrorCount: consoleErrors.length, failed: failed.slice(0, 15), failedCount: failed.length, badResponses: badResponses.slice(0, 15), badResponseCount: badResponses.length });
    await ctx.close();
  }
  await browser.close();
  fs.writeFileSync(`${OUT}/probe-results.json`, JSON.stringify(results, null, 2));
  console.log(JSON.stringify(results, null, 2));
})().catch(e => { console.error('PROBE FAILED', e); process.exit(1); });
