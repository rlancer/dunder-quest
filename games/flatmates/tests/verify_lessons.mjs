// Runs every lesson card's snippet under Node and checks what it prints.
// Cards with an "output" list must log exactly those lines, in order; the
// rest must at least parse and run against stand-ins for the game's objects.
//
//   node tests/verify_lessons.mjs   ->  LESSONS result=ok

import { readFileSync } from "node:fs";

const bank = JSON.parse(readFileSync(new URL("../data/lessons.json", import.meta.url), "utf8"));
const fails = [];

// Stand-ins for things in the game: a flatmate takes steps, a bell rings.
function flatmate() {
  return new Proxy({}, { get: () => () => Promise.resolve() });
}
class Bell extends EventTarget {
  ring() { this.dispatchEvent(new Event("ring")); }
}

async function run(card) {
  const logs = [];
  const log = (...args) => logs.push(args.map(String).join(" "));
  const body = `return (async () => {\n${card.code.join("\n")}\n})();`;
  const fn = new Function("console", "jazz", "clive", "bell", body);
  await fn({ log }, flatmate(), flatmate(), new Bell());
  // Let timers and promises in the snippet finish.
  await new Promise((done) => setTimeout(done, 3000));
  return logs;
}

const runs = [];
for (const [stage, lesson] of Object.entries(bank)) {
  for (const card of lesson.cards) {
    runs.push(run(card).then((logs) => {
      if (card.output && JSON.stringify(logs) !== JSON.stringify(card.output)) {
        fails.push(`${stage}/${card.id}: printed ${JSON.stringify(logs)}, card says ${JSON.stringify(card.output)}`);
      }
    }, (error) => fails.push(`${stage}/${card.id}: ${error.message}`)));
  }
}
await Promise.all(runs);
for (const fail of fails) console.log("FAIL", fail);
console.log(`LESSONS result=${fails.length ? "FAIL" : "ok"}`);
process.exit(fails.length ? 1 : 0);
