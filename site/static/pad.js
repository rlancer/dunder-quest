// Barry's legal pads on the Curb Your Oxidation page, like the game's pad:
// tap a blank to cycle through its options, then Run it. The verdict for
// every combination of blanks comes from the in-game checker, in the pad's
// data-verdicts: Sharon's interruption, or the scene playing out.
(function () {
  function line(who, text) {
    const p = document.createElement("p");
    const b = document.createElement("b");
    b.textContent = who;
    p.append(b, " " + text);
    return p;
  }

  function block(lines, cls) {
    const pre = document.createElement("pre");
    pre.className = cls;
    pre.textContent = lines.join("\n");
    return pre;
  }

  const TITLES = { ok: "It compiles. And then it happens.", wrong: "It compiles. It just isn't what happened.",
    panic: "It compiles. Then it panics.", err: "Sharon has a problem with line " };

  document.querySelectorAll("[data-pad]").forEach(function (pad) {
    const verdicts = JSON.parse(pad.dataset.verdicts);
    const blanks = Array.from(pad.querySelectorAll(".blank"));
    const run = pad.querySelector(".run");
    const out = pad.querySelector(".pad-out");

    blanks.forEach(function (blank) {
      const options = JSON.parse(blank.dataset.options);
      blank.disabled = false;
      blank.addEventListener("click", function () {
        const pick = (Number(blank.dataset.pick) + 1) % options.length;
        blank.dataset.pick = String(pick);
        blank.textContent = options[pick] || "…";
        blank.classList.add("set");
        out.hidden = true;
      });
    });

    run.disabled = false;
    run.addEventListener("click", function () {
      const key = blanks.map(function (b) { return b.dataset.pick; }).join(",");
      const v = verdicts[key];
      if (!v) return;
      out.replaceChildren();
      out.className = "pad-out " + v.kind;
      const title = document.createElement("p");
      title.className = "pad-verdict";
      title.textContent = v.kind === "err" ? TITLES.err + v.at.split(":").pop() + "." : TITLES[v.kind];
      out.append(title);
      if (v.kind === "err") out.append(block([v.head, "  " + v.at], "rustc"));
      else if (v.out.length) out.append(block(v.out, "stdout"));
      v.lines.forEach(function (l) { out.append(line(l[0], l[1])); });
      out.hidden = false;
    });
    pad.classList.add("live");
  });
})();
