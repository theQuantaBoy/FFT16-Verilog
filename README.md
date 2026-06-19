# FFT16-Verilog

A 16-point [Radix-2 Decimation-in-Time (DIT)](https://en.wikipedia.org/wiki/Cooley%E2%80%93Tukey_FFT_algorithm) [Fast Fourier Transform](https://en.wikipedia.org/wiki/Fast_Fourier_transform) implemented in Verilog using Q15 fixed-point arithmetic. The design is built hierarchically from a single behavioral 2-point butterfly unit, with two independent structural implementations of the full 16-point transform.

Originally developed as part of the Digital Systems Design (DSD) course midterm exam, Spring 2026, at Sharif University of Technology (Dr. Ejlali).

---

## Features

- Behavioral 2-point DFT butterfly (`FFT_2pt`) as the sole arithmetic primitive
- Two structural 16-point FFT implementations with identical interfaces (see below)
- Q15 fixed-point arithmetic — no floating point anywhere in the design
- Output grows by one guard bit per stage; no overflow is possible
- Twiddle factors W<sub>16</sub><sup>0..7</sup> stored in a shared combinational LUT (`w_lut`)
- Self-checking testbench with 6 curated test vectors
- Python-driven randomized testing, verified against NumPy's FFT

---

## Project Structure

```
FFT-16pt/
├── src/
│   ├── FFT_2pt.v        # Behavioral 2-point butterfly (base unit)
│   ├── FFT_4pt.v        # Structural 4-point FFT
│   ├── FFT_8pt.v        # Structural 8-point FFT
│   ├── FFT_16pt.v       # Structural 16-point FFT (hierarchical)
│   ├── FFT_16pt_flat.v  # Structural 16-point FFT (flat, 32 × FFT_2pt)
│   └── w_lut.v          # Twiddle factor LUT
├── test/
│   ├── testbench.v          # Self-checking testbench (6 fixed test vectors)
│   ├── python_testbench.v   # Verilog side of the randomized tester
│   └── run_random.py        # Python randomized test runner
├── build/               # Generated (gitignored)
└── .gitignore
```

---

## The Two 16-point Implementations

### `FFT_16pt` — Hierarchical

Follows the standard Radix-2 DIT decomposition recursively. The 16 inputs are split into even and odd sub-sequences, each processed by an `FFT_8pt`, and the results are combined with 8 final butterfly units.

```
FFT_16pt
├── FFT_8pt (even indices: x[0], x[2], ..., x[14])
│   ├── FFT_4pt
│   │   ├── FFT_2pt  ×2  (stage 1)
│   │   └── FFT_2pt  ×2  (stage 2)
│   └── FFT_4pt
│       └── ...
├── FFT_8pt (odd indices: x[1], x[3], ..., x[15])
│   └── ...
└── FFT_2pt  ×8  (stage 4 — final merge)
```

### `FFT_16pt_flat` — Flat

Instantiates all 32 butterfly units directly, with bit-reversal permutation applied to the inputs. No intermediate sub-FFT modules — every `FFT_2pt` appears explicitly across 4 named stages.

```
FFT_16pt_flat
├── Stage 1  (stride 1, W=1):          8 × FFT_2pt #(DW)
├── Stage 2  (stride 2, W=1 or −j):   8 × FFT_2pt #(DW+1)
├── Stage 3  (stride 4, W=W₁₆^{0,2,4,6}):  8 × FFT_2pt #(DW+2)
└── Stage 4  (stride 8, W=W₁₆^{0..7}):     8 × FFT_2pt #(DW+3)
```

Both modules share the same port interface and produce bit-for-bit identical outputs.

### Bit-width growth

Each butterfly adds one guard bit to prevent overflow. For the default `DW=16`:

| Stage | Input width | Output width |
|---|---|---|
| 1 | 16 bits | 17 bits |
| 2 | 17 bits | 18 bits |
| 3 | 18 bits | 19 bits |
| 4 | 19 bits | **20 bits** |

The 20-bit outputs hold exact integer DFT values (no 1/N normalization).

---

## Running the Tests

All commands are run from the project root. The `build/` directory is created automatically.

### Per-module inline testbenches

```bash
# 2-point butterfly
iverilog -D TEST_FFT_2PT -o build/sim src/FFT_2pt.v && vvp build/sim

# 4-point FFT
iverilog -D TEST_FFT_4PT -o build/sim src/FFT_4pt.v src/FFT_2pt.v src/w_lut.v && vvp build/sim

# 8-point FFT
iverilog -D TEST_FFT_8PT -o build/sim src/FFT_8pt.v src/FFT_4pt.v src/FFT_2pt.v src/w_lut.v && vvp build/sim
```

### Self-checking testbench (6 fixed vectors)

```bash
# Hierarchical (FFT_16pt)
iverilog -o build/sim test/testbench.v src/FFT_16pt.v src/FFT_8pt.v src/FFT_4pt.v src/FFT_2pt.v src/w_lut.v && vvp build/sim

# Flat (FFT_16pt_flat)
iverilog -D USE_FLAT -o build/sim test/testbench.v src/FFT_16pt_flat.v src/FFT_2pt.v src/w_lut.v && vvp build/sim
```

The 6 test vectors and the reasoning behind each:

| # | Input | Why it's useful |
|---|---|---|
| TC1 | DC: `{1, 1, ..., 1}` | All energy in X[0]; verifies accumulation |
| TC2 | Nyquist: `{1, −1, 1, −1, ...}` | All energy in X[8]; verifies alternating-sign paths |
| TC3 | Impulse at n=0 | Flat spectrum: X[k]=1 for all k |
| TC4 | Impulse at n=4 | X[k] rotates by −90° per bin; stresses every twiddle |
| TC5 | Cosine at bin 2 | Energy only at X[2] and X[14]; verifies symmetry |
| TC6 | Sawtooth 0→1 | Multi-bin spectrum; general correctness |

### Randomized testing against NumPy

```bash
python3 test/run_random.py 20          # 20 random cases, FFT_16pt
python3 test/run_random.py 20 --flat   # 20 random cases, FFT_16pt_flat
```

The script generates random 16-bit signed inputs, runs them through the Verilog simulation, and compares each output bin against NumPy's FFT. Pass criterion: |got − expected| ≤ 64 LSBs per component (accounts for Q15 twiddle truncation, empirically ≤ 32 LSBs across 4 stages).

**Terminal output:**

```
Running 20 random test case(s) against FFT_16pt...

TC01: PASS
TC02: PASS
...
TC20: PASS

SUMMARY: 20/20 passed  — all tests PASSED
Full results: build/test_results.log
```

A full expected/got table for every bin of every test case is written to `build/test_results.log`.

---

## Requirements

**Simulation:** [Icarus Verilog](https://github.com/steveicarus/iverilog) (`iverilog`, `vvp`)

**Randomized testing:** Python 3 with [NumPy](https://numpy.org/)