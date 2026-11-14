import "@fontsource/atkinson-hyperlegible-next/latin-400.css";
import "@fontsource/atkinson-hyperlegible-next/latin-700.css";
import "./styles.css";
import { Game } from "./ui";

const game = new Game(document.getElementById("root")!);
// For poking at it from the console: __game.begin(3) opens the fourth job.
if (import.meta.env.DEV) (window as unknown as { __game: Game }).__game = game;
