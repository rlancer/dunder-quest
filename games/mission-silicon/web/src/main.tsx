import "@fontsource/atkinson-hyperlegible-next/latin-400.css";
import "@fontsource/atkinson-hyperlegible-next/latin-700.css";
import "@fontsource/montserrat/latin-800.css";
import "@fontsource/pixelify-sans/latin-400.css";
import "./styles.css";
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import Pilot from "./Pilot";

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <Pilot />
  </StrictMode>,
);
