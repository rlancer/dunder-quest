import "@fontsource/atkinson-hyperlegible-next/latin-400.css";
import "@fontsource/atkinson-hyperlegible-next/latin-700.css";
import "@fontsource/pixelify-sans/latin-400.css";
import "@fontsource/pixelify-sans/latin-700.css";
import "./styles.css";
import { type Style, move } from "./bots";
import { Game } from "./ui";

const game = new Game(document.getElementById("root")!);

if (import.meta.env.DEV) {
  // For poking at it from the console: __game.start(3), or __bot("lazy") to
  // have one of the tests' players take over the hands.
  const dev = window as unknown as {
    __game: Game;
    __bot: (style: Style | null) => void;
    __step: (secs: number, style?: Style) => string;
  };
  let timer = 0;
  dev.__game = game;
  // Run the clock by hand (a hidden tab gets no animation frames), with a
  // bot's hands or none: __step(5, "careful").
  dev.__step = (secs, style) => {
    const g = game as unknown as { pulses: Set<string>; paused: boolean; pump: () => void };
    let hand = 0;
    for (let t = 0; t < secs; t += 1 / 30) {
      game.frame(1 / 30);
      hand -= 1 / 30;
      if (style && hand <= 0 && game.engine && !g.paused && move(game.engine, style, g.pulses)) {
        hand = 0.5;
        g.pump();
      }
    }
    return game.engine ? `${game.engine.phase} ${game.engine.pt.toFixed(1)}` : "";
  };
  // http://localhost:5182/#3,40,careful,good opens on night 3, forty seconds
  // in, played by the careful bot, with a robot taught well on earlier nights.
  const [night, secs, style, carry] = location.hash.slice(1).split(",");
  if (night) {
    const good = { book: ["ledger"], pay: ["adder"], cancel: ["ledger"], ask: ["notes", "model"], free: ["notes", "ledger"] };
    const bad = { book: ["notes"], pay: ["stamp"], cancel: ["stamp"], ask: ["key"], free: ["ledger"] };
    const rules = Object.fromEntries(Object.entries(carry === "bad" ? bad : good).slice(0, Number(night) - 1));
    game.save = { next: Number(night), stars: [3, 2, 3].slice(0, Number(night) - 1), servers: 3, carry: { rules, ttl: carry !== "bad" && Number(night) > 3 } } as Game["save"];
    if (Number(night) <= 4) game.start(Number(night));
    else (game as unknown as { brief: () => void }).brief();
    dev.__step(Number(secs) || 0, (style || undefined) as Style | undefined);
  }
  dev.__bot = (style) => {
    clearInterval(timer);
    if (!style) return;
    const g = game as unknown as { pulses: Set<string>; paused: boolean; pump: () => void };
    timer = window.setInterval(() => {
      if (!game.engine || g.paused) return;
      move(game.engine, style, g.pulses);
      g.pump();
    }, 500);
  };
}
