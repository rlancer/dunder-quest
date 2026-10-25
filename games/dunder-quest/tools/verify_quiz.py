"""Run every lesson snippet and check it against what Python really prints.

Each snippet runs in its own isolated interpreter (`python -I`), so nothing
from this repo or the environment leaks in.

Wizard questions: the marked option must equal the captured stdout exactly
(one trailing newline stripped), and each must name a scroll from its stage
and carry a hint. A stage's `trial` (questions the wizard wants right) must
leave him at least twice that many to ask, so a miss still gets a fresh one.

Scrolls: every `print(...)  # value` line promises its output, and the
printed lines must match those comments in order. A scroll marked
`"raises": "TypeError"` must end with exactly that error.

The script also checks the shapes and that everything fits the 480x270
screen: the duel's question strip sets the code (left) beside the four
answers (right) at 6.4px a column, so 40 code columns and 24 answer columns
share one 456px row, and seven code lines keep the strip clear of the
answer blocks below it.

    python tools/verify_quiz.py
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BANK = ROOT / "data" / "lessons.json"

MIN_VERSION = (3, 12)
MIN_PER_STAGE = 6
MAX_TRIAL = 5
MAX_CODE_LINES = 7
MAX_CODE_COLS = 40
MAX_OPTION_COLS = 24
MAX_EXPLANATION = 88
MAX_HINT = 64
MIN_SCROLLS = 3
MAX_SCROLL_LINES = 5
MAX_SCROLL_COLS = 46
MAX_SCROLL_TITLE = 22
MAX_INSIGHT = 92
TIMEOUT = 10.0


def run_snippet(code: str) -> tuple[str, str, int]:
    completed = subprocess.run(
        [sys.executable, "-I", "-c", code],
        capture_output=True,
        text=True,
        encoding="utf-8",
        timeout=TIMEOUT,
        cwd=Path.home(),
    )
    return completed.stdout, completed.stderr, completed.returncode


def check_scroll(stage: str, scroll: dict) -> list[str]:
    tag = f"stage {stage} scroll {scroll.get('id', '?')}"
    problems: list[str] = []
    code_lines = scroll.get("code")
    if not isinstance(code_lines, list) or not code_lines or not all(isinstance(line, str) for line in code_lines):
        return [f"{tag}: code must be a non-empty list of lines"]
    for key in ("id", "title", "insight"):
        if not str(scroll.get(key, "")).strip():
            problems.append(f"{tag}: missing {key}")
    if len(str(scroll.get("title", ""))) > MAX_SCROLL_TITLE:
        problems.append(f"{tag}: title longer than {MAX_SCROLL_TITLE} chars")
    if len(str(scroll.get("insight", ""))) > MAX_INSIGHT:
        problems.append(f"{tag}: insight longer than {MAX_INSIGHT} chars")
    if len(code_lines) > MAX_SCROLL_LINES:
        problems.append(f"{tag}: {len(code_lines)} code lines (max {MAX_SCROLL_LINES})")
    promised: list[str] = []
    for line in code_lines:
        if len(line) > MAX_SCROLL_COLS:
            problems.append(f"{tag}: code line is {len(line)} cols (max {MAX_SCROLL_COLS}): {line!r}")
        if line.lstrip().startswith("print(") and "#" in line:
            promised.append(line.split("#", 1)[1].strip())
    stdout, stderr, code = run_snippet("\n".join(code_lines) + "\n")
    raises = scroll.get("raises")
    if raises:
        last = stderr.strip().splitlines()[-1:] or [""]
        if code == 0 or not last[0].startswith(f"{raises}:"):
            problems.append(f"{tag}: expected {raises}, got exit {code} {last}")
    elif code != 0 or stderr.strip():
        problems.append(f"{tag}: snippet failed: {stderr.strip().splitlines()[-1:]}")
    printed = stdout.splitlines()
    if printed != promised:
        problems.append(f"{tag}: printed {printed} but comments promise {promised}")
    status = "ok  " if not problems else "FAIL"
    print(f"{status} {tag}: {printed}")
    return problems


def check_question(stage: str, index: int, question: dict, scroll_ids: set[str]) -> list[str]:
    tag = f"stage {stage} #{index + 1}"
    problems: list[str] = []
    if question.get("scroll") not in scroll_ids:
        problems.append(f"{tag}: scroll {question.get('scroll')!r} is not one of this stage's scrolls")
    hint = str(question.get("hint", "")).strip()
    if not hint:
        problems.append(f"{tag}: missing hint")
    elif len(hint) > MAX_HINT:
        problems.append(f"{tag}: hint longer than {MAX_HINT} chars")
    code_lines = question.get("code")
    options = question.get("options")
    answer = question.get("answer")
    if not isinstance(code_lines, list) or not code_lines or not all(isinstance(line, str) for line in code_lines):
        return [f"{tag}: code must be a non-empty list of lines"]
    if not isinstance(options, list) or len(options) != 4 or not all(isinstance(o, str) for o in options):
        return [f"{tag}: needs exactly 4 string options"]
    if not isinstance(answer, int) or not 0 <= answer < 4:
        return [f"{tag}: answer must be an index 0-3"]
    for key in ("prompt", "explanation"):
        if not str(question.get(key, "")).strip():
            problems.append(f"{tag}: missing {key}")
    if len(set(options)) != 4:
        problems.append(f"{tag}: options are not distinct {options}")
    if len(code_lines) > MAX_CODE_LINES:
        problems.append(f"{tag}: {len(code_lines)} code lines (max {MAX_CODE_LINES})")
    for line in code_lines:
        if len(line) > MAX_CODE_COLS:
            problems.append(f"{tag}: code line is {len(line)} cols (max {MAX_CODE_COLS}): {line!r}")
        if "\t" in line:
            problems.append(f"{tag}: code line has a tab: {line!r}")
    for option in options:
        if len(option) > MAX_OPTION_COLS:
            problems.append(f"{tag}: option is {len(option)} cols (max {MAX_OPTION_COLS}): {option!r}")
        if "\n" in option:
            problems.append(f"{tag}: option spans lines: {option!r}")
    if len(str(question.get("explanation", ""))) > MAX_EXPLANATION:
        problems.append(f"{tag}: explanation longer than {MAX_EXPLANATION} chars")

    stdout, stderr, code = run_snippet("\n".join(code_lines) + "\n")
    if code != 0:
        problems.append(f"{tag}: snippet exited {code}: {stderr.strip().splitlines()[-1:]}")
    if stderr.strip():
        problems.append(f"{tag}: snippet wrote to stderr: {stderr.strip()}")
    printed = stdout[:-1] if stdout.endswith("\n") else stdout
    marked = options[answer]
    if printed != marked:
        problems.append(f"{tag}: printed {printed!r} but option {answer} is {marked!r}")
    for other, option in enumerate(options):
        if other != answer and option == printed:
            problems.append(f"{tag}: option {other} also matches the output")
    status = "ok  " if not problems else "FAIL"
    print(f"{status} {tag}: {printed!r}")
    return problems


def main() -> int:
    if sys.version_info < MIN_VERSION:
        print(f"QUIZ needs Python {MIN_VERSION[0]}.{MIN_VERSION[1]}+ (have {sys.version.split()[0]})")
        return 1
    bank = json.loads(BANK.read_text(encoding="utf-8"))
    problems: list[str] = []
    total = 0
    all_scroll_ids: set[str] = set()
    stages = sorted(bank, key=int)
    for stage in stages:
        lesson = bank.get(stage)
        if not isinstance(lesson, dict):
            problems.append(f"stage {stage}: missing lesson")
            continue
        for key in ("topic", "taunt"):
            if not str(lesson.get(key, "")).strip():
                problems.append(f"stage {stage}: missing {key}")
        scrolls = lesson.get("scrolls")
        if not isinstance(scrolls, list) or len(scrolls) < MIN_SCROLLS:
            problems.append(f"stage {stage}: needs at least {MIN_SCROLLS} scrolls")
            scrolls = []
        scroll_ids: set[str] = set()
        for scroll in scrolls:
            scroll_id = str(scroll.get("id", ""))
            if scroll_id in all_scroll_ids:
                problems.append(f"stage {stage}: duplicate scroll id {scroll_id!r}")
            all_scroll_ids.add(scroll_id)
            scroll_ids.add(scroll_id)
            problems.extend(check_scroll(stage, scroll))
        trial = lesson.get("trial")
        if not isinstance(trial, int) or not 1 <= trial <= MAX_TRIAL:
            problems.append(f"stage {stage}: trial must be 1-{MAX_TRIAL}, got {trial!r}")
            trial = 1
        questions = lesson.get("questions")
        wanted = max(MIN_PER_STAGE, trial * 2)
        if not isinstance(questions, list) or len(questions) < wanted:
            problems.append(f"stage {stage}: needs at least {wanted} questions")
            continue
        asked: set[str] = set()
        seen_code: set[str] = set()
        for index, question in enumerate(questions):
            total += 1
            asked.add(str(question.get("scroll")))
            problems.extend(check_question(stage, index, question, scroll_ids))
            key = "\n".join(question.get("code", []))
            if key in seen_code:
                problems.append(f"stage {stage} #{index + 1}: duplicate snippet")
            seen_code.add(key)
        for scroll_id in sorted(scroll_ids - asked):
            problems.append(f"stage {stage}: no question draws on scroll {scroll_id!r}")
    for problem in problems:
        print("  -", problem)
    counts = ", ".join(f"stage {s}={len(bank.get(s, {}).get('questions', []))}" for s in stages)
    result = "ok" if not problems else "fail"
    print(f"QUIZ result={result} questions={total} ({counts}) python={sys.version.split()[0]} problems={len(problems)}")
    return 0 if not problems else 1


if __name__ == "__main__":
    sys.exit(main())
