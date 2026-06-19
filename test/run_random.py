#!/usr/bin/env python3
"""
run_random.py — randomized testbench for FFT_16pt / FFT_16pt_flat

Usage (from project root):
    python3 test/run_random.py [N] [--flat]

    N       number of test cases (default: 10)
    --flat  test FFT_16pt_flat instead of FFT_16pt

Terminal output: PASS/FAIL per case; failing bins shown inline.
Full expected/got table for every case written to build/test_results.log.
"""

import numpy as np
import subprocess
import sys
import os
from datetime import datetime

TOLERANCE = 64


def parse_args():
    n_cases = 10
    use_flat = False
    for arg in sys.argv[1:]:
        if arg == "--flat":
            use_flat = True
        elif arg.lstrip("-").isdigit():
            n_cases = int(arg)
        else:
            print(f"Unknown argument: {arg}", file=sys.stderr)
            sys.exit(1)
    return n_cases, use_flat


def generate_inputs(n_cases):
    rng = np.random.default_rng()
    return rng.integers(-32768, 32768, size=(n_cases, 16), dtype=np.int16)


def write_hex(inputs, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        for case in inputs:
            for val in case:
                f.write(f"{int(val) & 0xFFFF:04x}\n")


def compile_verilog(n_cases, use_flat):
    os.makedirs("build", exist_ok=True)
    if use_flat:
        src = ["src/FFT_16pt_flat.v", "src/FFT_2pt.v", "src/w_lut.v"]
        flags = [f"-DN_CASES={n_cases}", "-DUSE_FLAT"]
    else:
        src = [
            "src/FFT_16pt.v",
            "src/FFT_8pt.v",
            "src/FFT_4pt.v",
            "src/FFT_2pt.v",
            "src/w_lut.v",
        ]
        flags = [f"-DN_CASES={n_cases}"]

    cmd = ["iverilog"] + flags + ["-o", "build/sim", "test/python_testbench.v"] + src
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print("Compilation failed:")
        print(result.stderr)
        sys.exit(1)


def run_simulation():
    result = subprocess.run(["vvp", "build/sim"], capture_output=True, text=True)
    if result.returncode != 0:
        print("Simulation failed:")
        print(result.stderr)
        sys.exit(1)
    return result.stdout


def parse_outputs(stdout, n_cases):
    actual_re = np.zeros((n_cases, 16), dtype=np.int64)
    actual_im = np.zeros((n_cases, 16), dtype=np.int64)
    for line in stdout.splitlines():
        if line.startswith("OUT"):
            parts = line.split()
            c, k = int(parts[1]), int(parts[2])
            actual_re[c][k] = int(parts[3])
            actual_im[c][k] = int(parts[4])
    return actual_re, actual_im


def compare_and_report(inputs, actual_re, actual_im, n_cases, module, log_path):
    expected = np.fft.fft(inputs.astype(np.float64), axis=1)

    passed, failed = 0, 0
    log_lines = []

    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    log_lines.append(f"{module} — {n_cases} random test case(s)")
    log_lines.append(f"Run at: {timestamp}")
    log_lines.append(f"Tolerance: ±{TOLERANCE} LSBs")
    log_lines.append("")

    for i in range(n_cases):
        exp_re = np.round(expected[i].real).astype(np.int64)
        exp_im = np.round(expected[i].imag).astype(np.int64)
        got_re = actual_re[i]
        got_im = actual_im[i]

        fail_bins = [
            k
            for k in range(16)
            if abs(got_re[k] - exp_re[k]) > TOLERANCE
            or abs(got_im[k] - exp_im[k]) > TOLERANCE
        ]

        status = "PASS" if not fail_bins else "FAIL"

        # ── terminal ──────────────────────────────────────────────
        print(f"TC{i+1:02d}: {status}")
        if fail_bins:
            for k in fail_bins:
                print(
                    f"  X[{k:2d}]: got {got_re[k]:+9d}{got_im[k]:+9d}j"
                    f"   exp {exp_re[k]:+9d}{exp_im[k]:+9d}j"
                )

        # ── log file (all bins, all cases) ────────────────────────
        log_lines.append(f"TC{i+1:02d}: {status}")
        log_lines.append(
            f'  {"bin":<4}  {"got_re":>10}  {"got_im":>10}  '
            f'{"exp_re":>10}  {"exp_im":>10}  {"err_re":>8}  {"err_im":>8}'
        )
        log_lines.append(
            f'  {"-"*4}  {"-"*10}  {"-"*10}  ' f'{"-"*10}  {"-"*10}  {"-"*8}  {"-"*8}'
        )
        for k in range(16):
            marker = " ← FAIL" if k in fail_bins else ""
            log_lines.append(
                f"  X[{k:2d}]  {got_re[k]:>10d}  {got_im[k]:>10d}  "
                f"{exp_re[k]:>10d}  {exp_im[k]:>10d}  "
                f"{got_re[k]-exp_re[k]:>+8d}  {got_im[k]-exp_im[k]:>+8d}{marker}"
            )
        log_lines.append("")

        if fail_bins:
            failed += 1
        else:
            passed += 1

    # ── summary ───────────────────────────────────────────────────
    summary = f"SUMMARY: {passed}/{n_cases} passed"
    summary += "  — all tests PASSED" if not failed else f"  ({failed} failed)"

    print(f"\n{summary}")
    log_lines += ["", summary]

    os.makedirs(os.path.dirname(log_path), exist_ok=True)
    with open(log_path, "w") as f:
        f.write("\n".join(log_lines) + "\n")
    print(f"Full results: {log_path}")


def main():
    n_cases, use_flat = parse_args()
    module = "FFT_16pt_flat" if use_flat else "FFT_16pt"
    log_path = "build/test_results.log"

    print(f"Running {n_cases} random test case(s) against {module}...\n")

    inputs = generate_inputs(n_cases)
    write_hex(inputs, "test/inputs.hex")
    compile_verilog(n_cases, use_flat)
    stdout = run_simulation()
    actual_re, actual_im = parse_outputs(stdout, n_cases)
    compare_and_report(inputs, actual_re, actual_im, n_cases, module, log_path)


if __name__ == "__main__":
    main()
