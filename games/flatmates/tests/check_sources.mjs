// Parses every script the bot solved (tests/out/*.mjs, written by
// tests/bot.gd) as a JavaScript module: what the laptop shows must be code
// that would really run.
//
//   node tests/check_sources.mjs   ->  SOURCES result=ok

import { readdirSync, readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";

const dir = new URL("./out/", import.meta.url);
const files = readdirSync(dir).filter((name) => name.endsWith(".mjs"));
let fails = 0;
for (const name of files) {
  const path = new URL(name, dir);
  const result = spawnSync(process.execPath, ["--check", path.pathname.replace(/^\/([A-Za-z]:)/, "$1")], { encoding: "utf8" });
  if (result.status !== 0) {
    fails += 1;
    console.log(`FAIL ${name}\n${readFileSync(path, "utf8")}\n${result.stderr}`);
  }
}
console.log(`SOURCES ${files.length} files result=${fails || files.length === 0 ? "FAIL" : "ok"}`);
process.exit(fails || files.length === 0 ? 1 : 0);
