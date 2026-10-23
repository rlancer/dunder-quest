// What the Brand pages show. Images come from the live site, so the pages
// show what's deployed rather than what's in the repo.
export const SITE = "https://dunderquest.com/";
export const IMG = `${SITE}static/img/`;
export const REPO = "https://github.com/rlancer/dunder-quest";

// Keep in step with TRAILER_ID in site/build.py.
export const TRAILER_ID = "dXOdBei8838";
export const TRAILER_URL = `https://www.youtube.com/watch?v=${TRAILER_ID}`;

// trailer/PLAN.md §4 has the game's palette; dusk, moss and zap are the
// site's additions in site/static/style.css.
export const PALETTE: { name: string; hex: string; use: string }[] = [
  { name: "Gold", hex: "#F2B544", use: "Headlines, the wordmark, strings in code" },
  { name: "Ember", hex: "#FF8A3D", use: "Accents, the wordmark's underscores, keywords in code" },
  { name: "Parchment", hex: "#F4E4C4", use: "Body text, numbers in code" },
  { name: "Ash", hex: "#B0A9D0", use: "Secondary text, comments in code" },
  { name: "Night", hex: "#15122A", use: "Backgrounds, card fills, text shadows" },
  { name: "Dusk", hex: "#232849", use: "The site's page background (the game's clear color)" },
  { name: "Line", hex: "#4A4F86", use: "Panel borders" },
  { name: "Moss", hex: "#7BE08A", use: "A cleared stage, right answers" },
  { name: "Zap", hex: "#FF7A7A", use: "Wrong answers, hits" },
];
