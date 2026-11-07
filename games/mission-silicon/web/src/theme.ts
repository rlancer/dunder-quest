// Light, dark, or the device's own setting ("auto", the default). The bar's
// theme button cycles them; the choice is kept in this browser and set as
// data-theme on <html>, which styles.css reads. index.html applies a saved
// choice before the first paint, so the page never flashes the wrong way.

import { useEffect, useState } from "react";

export type Theme = "auto" | "light" | "dark";
const KEY = "ms-theme";
const ORDER: Theme[] = ["auto", "light", "dark"];

function load(): Theme {
  try {
    const t = localStorage.getItem(KEY);
    return t === "light" || t === "dark" ? t : "auto";
  } catch {
    return "auto";
  }
}

export function useTheme(): [Theme, () => void] {
  const [theme, setTheme] = useState<Theme>(load);
  useEffect(() => {
    const root = document.documentElement;
    if (theme === "auto") delete root.dataset.theme;
    else root.dataset.theme = theme;
    try {
      if (theme === "auto") localStorage.removeItem(KEY);
      else localStorage.setItem(KEY, theme);
    } catch {}
  }, [theme]);
  return [theme, () => setTheme((t) => ORDER[(ORDER.indexOf(t) + 1) % ORDER.length])];
}
