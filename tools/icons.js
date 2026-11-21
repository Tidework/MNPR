// Makes the static app icons (icon-180.png, icon-512.png) from plateIcon() in the built page.
// Run after build.py: node tools/icons.js
const { chromium } = require("playwright");
const fs = require("fs"), path = require("path");
(async () => {
  const root = path.join(__dirname, "..");
  const b = await chromium.launch();
  const p = await b.newPage();
  await p.goto("file://" + path.join(root, "index.html"));
  for (const size of [180, 512]) {
    const url = await p.evaluate(s => plateIcon("MNPR", s).toDataURL("image/png"), size);
    fs.writeFileSync(path.join(root, `icon-${size}.png`), Buffer.from(url.split(",")[1], "base64"));
  }
  const n12 = await p.evaluate(() => plateIcon(12, 180).toDataURL("image/png"));
  fs.writeFileSync(process.argv[2] || "/dev/null", Buffer.from(n12.split(",")[1], "base64"));
  await b.close();
})();
