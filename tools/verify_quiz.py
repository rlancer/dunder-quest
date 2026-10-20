"""Run every wizard question and check the marked answer is what Python prints.

Each snippet runs in its own isolated interpreter (`python -I`), so nothing
from this repo or the environment leaks in. The marked option must equal the
captured stdout exactly (one trailing newline stripped). The script also checks
the bank's shape and that everything fits the 480x270 quiz panel.

    python tools/verify_quiz.py
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BANK = ROOT / "data" / "wizard_questions.json"

MIN_VERSION = (3, 12)
MIN_PER_STAGE = 6
MAX_CODE_LINES = 8
MAX_CODE_COLS = 40
MAX_OPTION_COLS = 28
MAX_EXPLANATION = 88
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


def check_question(stage: str, index: int, question: dict) -> list[str]:
    tag = f"stage {stage} #{index + 1}"
    problems: list[str] = []
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
    for stage in ("1", "2", "3"):
        questions = bank.get(stage)
        if not isinstance(questions, list) or len(questions) < MIN_PER_STAGE:
            problems.append(f"stage {stage}: needs at least {MIN_PER_STAGE} questions")
            continue
        seen_code: set[str] = set()
        for index, question in enumerate(questions):
            total += 1
            problems.extend(check_question(stage, index, question))
            key = "\n".join(question.get("code", []))
            if key in seen_code:
                problems.append(f"stage {stage} #{index + 1}: duplicate snippet")
            seen_code.add(key)
    for problem in problems:
        print("  -", problem)
    counts = ", ".join(f"stage {s}={len(bank.get(s, []))}" for s in ("1", "2", "3"))
    result = "ok" if not problems else "fail"
    print(f"QUIZ result={result} questions={total} ({counts}) python={sys.version.split()[0]} problems={len(problems)}")
    return 0 if not problems else 1


if __name__ == "__main__":
    sys.exit(main())
