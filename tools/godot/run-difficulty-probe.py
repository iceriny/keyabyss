"""Freeze current rules, run the formal Godot probe, and retain readable evidence."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
from datetime import datetime


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--label", required=True)
    parser.add_argument("--seed", default="curve-17")
    parser.add_argument("--book", default="")
    parser.add_argument("--scenario", default="")
    parser.add_argument("--vocabulary", default="mixed", choices=["mixed", "short", "long"])
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    if not args.label.replace("-", "").replace("_", "").isalnum():
        parser.error("label must contain only letters, numbers, hyphens or underscores")
    output = root / ".temp" / "difficulty-probe" / args.label
    output.mkdir(parents=True, exist_ok=False)
    sources = sorted((root / "game").rglob("*.gd")) + sorted((root / "game").rglob("*.tres"))
    sources += [root / name for name in ["tests/godot/difficulty_probe.gd", "tests/godot/difficulty_probe_actor.gd", "tests/godot/test_s2_run.gd", "tools/godot/run-difficulty-probe.py", "tools/godot/toolchain.json"]]
    hashes = {}
    for source in sources:
        relative = source.relative_to(root)
        target = output / "source" / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        hashes[relative.as_posix()] = hashlib.sha256(source.read_bytes()).hexdigest()
    engine_args = ["--headless", "--debug", "--script", "res://tests/godot/difficulty_probe.gd", "--", f"--out={output.as_posix()}", f"--seed={args.seed}", f"--vocabulary={args.vocabulary}"]
    for option in ("book", "scenario"):
        if getattr(args, option):
            engine_args.append(f"--{option}={getattr(args, option)}")
    def ps_literal(value):
        return "'" + value.replace("'", "''") + "'"
    invoke = "& " + ps_literal(str(root / "tools/godot/godot.ps1")) + " -Task run -EngineArguments @(" + ",".join(map(ps_literal, engine_args)) + "); exit $LASTEXITCODE"
    command = ["pwsh", "-NoProfile", "-Command", invoke]
    manifest = {"started": datetime.now().astimezone().isoformat(), "arguments": vars(args), "command": command, "sha256": hashes}
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    with (output / "output.log").open("w", encoding="utf-8") as log:
        process = subprocess.Popen(command, cwd=root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace")
        for line in process.stdout:
            log.write(line)
            log.flush()
            if "SCRIPT ERROR" in line or "ERROR:" in line:
                print(line.rstrip(), flush=True)
                subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                break
            if line.startswith(("PROBE ROOM", "PROBE SCENARIO", "DIFFICULTY PROBE")) or any(marker in line for marker in ("ERROR", "WARNING", "Error", "error")):
                print(line.rstrip(), flush=True)
        code = process.wait()
    manifest["exit_code"] = code
    manifest["finished"] = datetime.now().astimezone().isoformat()
    manifest["changed_during_run"] = [name for name, digest in hashes.items() if hashlib.sha256((root / name).read_bytes()).hexdigest() != digest]
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    result_path = output / "results.json"
    if result_path.exists():
        results = json.loads(result_path.read_text(encoding="utf-8"))
        lines = [f"# Difficulty probe: {args.label}", "", f"Seed: {args.seed}; vocabulary: {args.vocabulary}; checks: {results['checks']}; flow failures: {results['failures']}.", "", "| Scenario | Book | Completed rounds | Last mode / room | Outcome |", "| --- | --- | --- | --- | --- |"]
        for item in results["scenarios"]:
            lines.append(f"| {item['scenario']} | {item['book']} | {', '.join(item['completed_rounds']) or '—'} | {item['last_difficulty']} / {item['last_room']} | {item['last_result']} |")
        lines += ["", "## Parameters", "", "```json", json.dumps(results["parameters"], indent=2), "```", "", results["scope"], ""]
        (output / "summary.md").write_text("\n".join(lines), encoding="utf-8")
        code = code or int(results["failures"] > 0)
    else:
        code = code or 1
    log_text = (output / "output.log").read_text(encoding="utf-8")
    if any(marker in log_text for marker in ("SCRIPT ERROR", "WARNING:", "ERROR:")) or manifest["changed_during_run"]:
        code = code or 1
    manifest["validated_exit_code"] = code
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"Evidence: {output}; exit: {code}", flush=True)
    return code


if __name__ == "__main__":
    sys.exit(main())
