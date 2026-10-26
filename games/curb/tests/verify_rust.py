"""Holds the game's Rust up against the real rustc.

For every plan in data/scenes.json, in every combination of its blanks, it
compiles the program with rustc and (when it builds) runs it. Then it checks:

  * the starting picks fail with the error code the scene says,
  * the solution builds and prints exactly the lines the scene expects,
  * every lesson card builds and prints what it says (or fails with its code),
  * and, given tests/out/cases.json from the in-game checker
    (godot --headless --path . --script res://tests/cases.gd), that the
    checker agrees with rustc on every combination: same pass/fail, its
    first error code is one rustc reports, and the same output and panics.

    python tests/verify_rust.py              # RUST result=ok (skips if rustc is missing)
    python tests/verify_rust.py --require    # fail if rustc is missing (CI)

Needs rustc on the PATH (any recent stable, edition 2021).
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from itertools import product
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = json.loads((ROOT / "data" / "scenes.json").read_text(encoding="utf-8"))
CASES = ROOT / "tests" / "out" / "cases.json"
OPEN, CLOSE = "«", "»"


def slot_order(code: list[str]) -> list[str]:
    order: list[str] = []
    for line in code:
        at = line.find(OPEN)
        while at >= 0:
            close = line.find(CLOSE, at)
            name = line[at + 1:close]
            if name not in order:
                order.append(name)
            at = line.find(OPEN, close)
    return order


def render(plan: dict, picks: dict[str, str]) -> str:
    lines = []
    for line in plan["code"]:
        for name, value in picks.items():
            line = line.replace(f"{OPEN}{name}{CLOSE}", value)
        lines.append(line)
    return "\n".join(lines) + "\n"


def combos(plan: dict) -> list[dict[str, str]]:
    order = slot_order(plan["code"])
    out = []
    for values in product(*(plan["slots"][name] for name in order)):
        out.append(dict(zip(order, values)))
    return out


def rustc(source: str, work: Path) -> dict:
    """Compile and run one program: {ok, codes, stdout, panic}."""
    src = work / "main.rs"
    exe = work / ("main.exe" if os.name == "nt" else "main")
    src.write_text(source, encoding="utf-8")
    build = subprocess.run(
        ["rustc", "--edition", "2021", "-A", "warnings", "--error-format=json", "-o", str(exe), str(src)],
        capture_output=True, text=True, encoding="utf-8", cwd=work,
    )
    if build.returncode != 0:
        codes = []
        for line in build.stderr.splitlines():
            try:
                diag = json.loads(line)
            except json.JSONDecodeError:
                continue
            if diag.get("level") == "error":
                codes.append((diag.get("code") or {}).get("code") or "")
        return {"ok": False, "codes": codes, "stdout": [], "panic": False}
    run = subprocess.run([str(exe)], capture_output=True, text=True, encoding="utf-8", timeout=20)
    return {"ok": True, "codes": [], "stdout": run.stdout.splitlines(), "panic": run.returncode == 101}


def card_source(card: dict) -> str:
    code = "\n".join(card["code"])
    if "fn main(" in code:
        return code + "\n"
    return "fn main() {\n" + "\n".join("    " + line for line in card["code"]) + "\n}\n"


def main() -> None:
    if shutil.which("rustc") is None:
        print("RUST result=skipped: rustc is not on the PATH (install Rust from https://rustup.rs)")
        sys.exit(1 if "--require" in sys.argv else 0)
    version = subprocess.run(["rustc", "--version"], capture_output=True, text=True).stdout.strip()
    print(f"using {version}")

    jobs: list[tuple[str, str, object]] = []  # (kind, key, payload)
    plans = {}
    for scene in DATA["scenes"]:
        for plan in scene["plans"]:
            plans[plan["id"]] = plan
            for picks in combos(plan):
                jobs.append(("plan", plan["id"], render(plan, picks)))
    for cid, card in DATA["cards"].items():
        jobs.append(("card", cid, card_source(card)))

    def work(job: tuple[str, str, object]) -> tuple[tuple[str, str, object], dict]:
        with tempfile.TemporaryDirectory() as tmp:
            return job, rustc(str(job[2]), Path(tmp))

    with ThreadPoolExecutor(max_workers=os.cpu_count() or 4) as pool:
        results = list(pool.map(work, jobs))
    by_source = {(job[1], job[2]): result for job, result in results if job[0] == "plan"}

    fails: list[str] = []
    for pid, plan in plans.items():
        start = by_source[(pid, render(plan, plan["start"]))]
        want = plan.get("start_error")
        if want and (start["ok"] or want not in start["codes"]):
            fails.append(f"{pid}: start picks gave {start['codes'] or 'ok'}, the scene says {want}")
        solved = by_source[(pid, render(plan, plan["solution"]))]
        if not solved["ok"]:
            fails.append(f"{pid}: solution fails to build: {solved['codes']}")
        elif solved["stdout"] != plan["expect"] or solved["panic"]:
            fails.append(f"{pid}: solution printed {solved['stdout']}, the scene expects {plan['expect']}")
    for job, result in results:
        if job[0] != "card":
            continue
        card = DATA["cards"][job[1]]
        if "error" in card:
            if result["ok"] or card["error"] not in result["codes"]:
                fails.append(f"card {job[1]}: expected {card['error']}, rustc gave {result['codes'] or 'ok'}")
        elif not result["ok"]:
            fails.append(f"card {job[1]}: fails to build: {result['codes']}")
        elif "output" in card and result["stdout"] != card["output"]:
            fails.append(f"card {job[1]}: printed {result['stdout']}, the card says {card['output']}")

    compared = 0
    if CASES.exists():
        for case in json.loads(CASES.read_text(encoding="utf-8")):
            truth = by_source.get((case["plan"], case["source"]))
            if truth is None:
                fails.append(f"{case['plan']}: cases.json is stale (re-run tests/cases.gd)")
                break
            compared += 1
            label = f"{case['plan']} {json.dumps(case['picks'])}"
            if case["ok"] != truth["ok"]:
                fails.append(f"{label}: checker says {'ok' if case['ok'] else case['codes'][:1]}, rustc says {'ok' if truth['ok'] else truth['codes']}")
            elif not truth["ok"] and case["codes"][0] not in truth["codes"]:
                fails.append(f"{label}: checker's {case['codes'][0]} isn't among rustc's {truth['codes']}")
            elif truth["ok"] and (case["stdout"] != truth["stdout"] or bool(case["panic"]) != truth["panic"]):
                fails.append(f"{label}: checker ran {case['stdout']} (panic {bool(case['panic'])}), binary printed {truth['stdout']} (panic {truth['panic']})")
    else:
        print("note: no tests/out/cases.json, so the in-game checker wasn't compared (run tests/cases.gd first)")

    for fail in fails:
        print("FAIL", fail)
    print(f"RUST {len(jobs)} programs built, {compared} checker verdicts compared, result={'FAIL' if fails else 'ok'}")
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
