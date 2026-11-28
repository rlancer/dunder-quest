// The laptops on the Flatmates.js page, like the game's editor: tap the blank
// to cycle through the options (or tap one), then Run to see what happens.
(function () {
  document.querySelectorAll<HTMLElement>("[data-laptop]").forEach(function (laptop) {
    const blank = laptop.querySelector<HTMLButtonElement>(".blank")!;
    const picks = Array.from(laptop.querySelectorAll<HTMLButtonElement>(".pick"));
    const run = laptop.querySelector<HTMLButtonElement>(".run")!;
    const out = laptop.querySelector<HTMLElement>(".out")!;
    let choice = -1;

    function choose(i: number): void {
      choice = i;
      blank.textContent = picks[i].textContent === "(nothing)" ? " " : picks[i].textContent;
      blank.classList.add("set");
      picks.forEach(function (pick, j) { pick.setAttribute("aria-pressed", String(i === j)); });
      run.disabled = false;
      out.hidden = true;
    }

    blank.disabled = false;
    picks.forEach(function (pick, i) {
      pick.disabled = false;
      pick.addEventListener("click", function () { choose(i); });
    });
    blank.addEventListener("click", function () { choose((choice + 1) % picks.length); });
    run.addEventListener("click", function () {
      const ok = picks[choice].dataset.ok === "true";
      out.className = "out " + (ok ? "right" : "wrong");
      out.querySelector("b")!.textContent = ok ? "It works." : "Not quite.";
      out.querySelector("span")!.textContent = picks[choice].dataset.result ?? null;
      out.hidden = false;
    });
    laptop.classList.add("live");
  });
})();
