// Smoke test for the templated build: run `npm run check`.
// Asserts the rendered pages are complete and share one footer/header.
const fs = require("fs");
const path = require("path");

const OUT = path.join(__dirname, "_site");
const PAGES = ["index.html", "join.html", "calendar.html"];

const read = (f) => fs.readFileSync(path.join(OUT, f), "utf8");
const fail = (msg) => {
  console.error(`FAIL ${msg}`);
  process.exitCode = 1;
};

const footerOf = (html) => {
  const m = html.match(/<footer[\s\S]*?<\/footer>/);
  return m ? m[0] : null;
};

const htmls = {};
for (const page of PAGES) {
  if (!fs.existsSync(path.join(OUT, page))) {
    fail(`${page} not built`);
    continue;
  }
  const html = (htmls[page] = read(page));

  if (/{{|{%/.test(html)) fail(`${page} has unrendered template syntax`);
  if (!html.includes('<header class="header">')) fail(`${page} missing header`);
  if (!html.includes('class="mobile-menu"')) fail(`${page} missing mobile menu`);
  if (!html.includes("function toggleMenu()")) fail(`${page} missing toggleMenu script`);
  if (!footerOf(html)) fail(`${page} missing footer`);

  const title = html.match(/<title>(.*?)<\/title>/);
  if (!title || !title[1]) fail(`${page} missing title`);
  else console.log(`ok ${page} (title: ${title[1]})`);
}

if (htmls["index.html"] && htmls["join.html"] && htmls["calendar.html"]) {
  const norm = (s) => s.replaceAll("index.html#", "#");
  const base = norm(footerOf(htmls["index.html"]));
  for (const page of ["join.html", "calendar.html"]) {
    if (norm(footerOf(htmls[page])) !== base) {
      fail(`${page} footer differs from index (beyond the index.html# prefix)`);
    }
  }
  if (!process.exitCode) console.log(`ok footer shared across all pages (${base.length} bytes)`);
}

if (htmls["index.html"]) {
  const h = htmls["index.html"];
  const blocks = {
    "welcome eyebrow": "Welcome to Albany Cub Scouts Pack 3",
    "welcome heading accent": "skits, badges, and outdoor fun?",
    "welcome values": "Building strong moral values",
    "welcome markdown rendered": "<strong>Cub Scouting means",
  };
  for (const [what, needle] of Object.entries(blocks)) {
    if (!h.includes(needle)) fail(`index.html missing ${what}`);
    else console.log(`ok index.html ${what}`);
  }
  if (h.includes("**Cub Scouting")) fail(`index.html has unrendered markdown`);
}
