// Practice run of a stage wizard's trial, following the game's rules: each
// right answer breaks one ward, a wrong one zaps you and he asks something
// new, and questions never repeat until the bank runs dry. Two hints per
// question: his riddle plus the scroll it draws on, then one wrong option dimmed.
(function () {
  const root = document.querySelector("[data-trial]");
  const source = document.getElementById("trial-data");
  if (!root || !source) return;
  const data = JSON.parse(source.textContent);
  const LETTERS = ["A", "B", "C", "D", "E", "F"];

  let owed, deck, current, hintLevel, dimmed, answered, asked, misses;

  function shuffle(list) {
    const a = list.slice();
    for (let i = a.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [a[i], a[j]] = [a[j], a[i]];
    }
    return a;
  }

  function el(tag, attrs, children) {
    const node = document.createElement(tag);
    for (const [key, value] of Object.entries(attrs || {})) {
      if (key === "html") node.innerHTML = value;
      else if (key === "text") node.textContent = value;
      else if (key.startsWith("on")) node.addEventListener(key.slice(2), value);
      else node.setAttribute(key, value);
    }
    for (const child of children || []) if (child) node.append(child);
    return node;
  }

  function start() {
    owed = data.trial;
    deck = [];
    asked = 0;
    misses = 0;
    next();
  }

  function next() {
    if (deck.length === 0) deck = shuffle(data.questions.map((_, i) => i));
    current = data.questions[deck.pop()];
    hintLevel = 0;
    dimmed = new Set();
    answered = false;
    asked += 1;
    render();
    const first = root.querySelector(".options button");
    if (first && asked > 1) first.focus();
  }

  function wards() {
    const box = el("div", { class: "wards", role: "img", "aria-label": `${owed} of ${data.trial} wards left` });
    for (let i = 0; i < data.trial; i++) box.append(el("span", { class: "ward" + (i >= owed ? " broken" : "") }));
    return box;
  }

  function render(verdict) {
    root.replaceChildren();
    root.append(el("div", { class: "trial-top" }, [
      el("span", { class: "trial-who", text: `${data.wizard} · question ${asked}` }),
      wards(),
    ]));
    root.append(el("figure", { class: "code" }, [el("pre", {}, [el("code", { html: current.code })])]));
    root.append(el("p", { class: "trial-prompt", text: current.prompt }));

    const list = el("ul", { class: "options" });
    current.options.forEach((option, index) => {
      let cls = "";
      if (dimmed.has(index)) cls = "dim";
      if (answered && index === current.answer) cls = "right";
      if (answered && verdict && verdict.pick === index && index !== current.answer) cls = "wrong";
      const button = el("button", {
        type: "button", class: cls, onclick: () => choose(index),
      }, [el("span", { class: "letter", text: LETTERS[index] }), el("span", { text: option })]);
      if (answered || dimmed.has(index)) button.disabled = true;
      list.append(el("li", {}, [button]));
    });
    root.append(list);

    if (hintLevel > 0 && !answered) {
      const box = el("div", { class: "hint" }, [el("q", { text: current.hint || "Think." })]);
      if (current.scroll) {
        box.append(el("p", { text: `From the scroll “${current.scroll}”: ${current.insight}` }));
      }
      if (hintLevel > 1) box.append(el("p", { text: `${data.wizard}'s eyes slide away from one answer. He says no more.` }));
      root.append(box);
    }

    if (verdict) {
      const right = verdict.pick === current.answer;
      root.append(el("div", { class: "verdict " + (right ? "right" : "wrong"), role: "status" }, [
        el("b", { text: right ? (owed === 0 ? "The last ward breaks!" : "A ward breaks.") : "Zapped! The answer was " + LETTERS[current.answer] + "." }),
        el("span", { text: current.explanation }),
      ]));
    }

    const actions = el("div", { class: "trial-actions" });
    if (answered) {
      const label = owed === 0 ? "Finish the trial" : "Next question";
      actions.append(el("button", { type: "button", onclick: owed === 0 ? banish : next, text: label }));
    } else {
      const canHint = hintLevel < 2 && current.options.length - 1 > dimmed.size;
      const hint = el("button", {
        type: "button", class: "quiet", onclick: askHint,
        text: hintLevel === 0 ? "Ask for a hint" : hintLevel === 1 ? "Ask again" : "No more hints",
      });
      hint.disabled = !canHint;
      actions.append(hint);
    }
    root.append(actions);
  }

  function askHint() {
    if (hintLevel >= 2 || answered) return;
    hintLevel += 1;
    if (hintLevel === 2) {
      const wrong = current.options.map((_, i) => i).filter((i) => i !== current.answer && !dimmed.has(i));
      if (wrong.length) dimmed.add(wrong[Math.floor(Math.random() * wrong.length)]);
    }
    render();
  }

  function choose(index) {
    if (answered) return;
    answered = true;
    if (index === current.answer) {
      owed -= 1;
    } else {
      misses += 1;
      root.classList.remove("shake");
      void root.offsetWidth;
      root.classList.add("shake");
    }
    render({ pick: index });
    const button = root.querySelector(".trial-actions button");
    if (button) button.focus();
  }

  function banish() {
    root.replaceChildren(el("div", { class: "banished", role: "status" }, [
      wards(),
      el("h3", { text: `${data.wizard} is banished` }),
      el("p", { text: misses === 0
        ? `${data.trial} for ${data.trial}, without a single zap. His barrier is gone.`
        : `It took ${asked} questions and ${misses} zap${misses === 1 ? "" : "s"}. His barrier is gone.` }),
      el("div", { class: "trial-actions", style: "justify-content:center" }, [
        el("button", { type: "button", onclick: start, text: "Sit the trial again" }),
      ]),
    ]));
    root.querySelector(".banished button").focus();
  }

  start();
})();
