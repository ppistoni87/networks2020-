# Local Development Guide

This guide explains how to set up and run the networks2020 project on your local machine.

## Prerequisites

| Dependency | Version | Notes |
|---|---|---|
| Python | >= 3.6 | [python.org](https://www.python.org/) |
| CMake | >= 2.8.4 | `sudo apt-get install cmake` |
| g++ / C++14 | >= 5.0 | `sudo apt-get install build-essential` |
| Boost Graph Library | >= 1.66 | `sudo apt-get install libboost-all-dev` or via Conan (see below) |
| IBM CPLEX | >= 12.8 | [ibm.com/products/ilog-cplex-optimization-studio](https://www.ibm.com/products/ilog-cplex-optimization-studio) |

> **Note:** CPLEX is a commercial product. IBM offers a free Community Edition with limited problem sizes.

---

## Quick setup

Run the setup script from the repository root:

```bash
bash setup_dev.sh
```

The script installs Boost automatically via `apt` when available, or falls back to
**[Conan](https://conan.io/)** (installed via `pip3 install conan` if needed).

If you already have CPLEX installed, pass the paths directly:

```bash
bash setup_dev.sh \
  --cplex-include /opt/ibm/ILOG/CPLEX_Studio129/cplex/include \
  --cplex-bin     /opt/ibm/ILOG/CPLEX_Studio129/cplex/lib/x86-64_linux/static_pic/libcplex.a
```

The script will:
1. Verify Python, CMake, and g++ are installed (and install missing apt packages).
2. Install Boost Graph Library if missing.
3. Auto-detect or use the provided CPLEX paths.
4. Write a `.env` file with all required environment variables.
5. Create the `output/` directory.

---

## Manual setup

### 1. Install system dependencies

```bash
sudo apt-get update
sudo apt-get install -y cmake build-essential libboost-all-dev
```

If `apt` is not available or has no network access, install Boost via Conan:

```bash
pip3 install conan
conan profile detect
conan install --requires="boost/1.83.0" --options "boost/*:without_graph=False" --build=missing
```

The setup script does this automatically as a fallback.

### 2. Install CPLEX

Download and install IBM CPLEX Optimization Studio from the IBM website. After installation, note the paths to:
- The `include` directory (contains `ilcplex/cplex.h`)
- The `libcplex.a` static library

### 3. Set environment variables

Copy the template and fill in your paths:

```bash
cp .env.example .env
# Edit .env with your CPLEX paths
source .env
```

Or export them directly in your shell session / `~/.bashrc`:

```bash
export BOOST_INCLUDE=/usr/include
export BOOST_BIN=/usr/lib/x86_64-linux-gnu/libboost_graph.a
export CPLEX_INCLUDE=/opt/ibm/ILOG/CPLEX_Studio129/cplex/include
export CPLEX_BIN=/opt/ibm/ILOG/CPLEX_Studio129/cplex/lib/x86-64_linux/static_pic/libcplex.a
```

---

## Running experiments

Make sure environment variables are set (`source .env`), then:

```bash
python3 runner/runner.py experiments/pricing.json
```

Available experiment files (in `experiments/`):

| File | Article section |
|---|---|
| `pricing.json` | Section 7.1 |
| `bp.json` | Section 7.2 |
| `bp_heur.json` | Section 7.4 |

### Useful runner flags

```bash
# Run only specific instances
python3 runner/runner.py experiments/pricing.json --instances <instance_name>

# Run only specific experiments within a file
python3 runner/runner.py experiments/pricing.json --exps <experiment_name>

# Set a memory limit (default 15 GB)
python3 runner/runner.py experiments/pricing.json --memlimit 8

# Suppress verbose output
python3 runner/runner.py experiments/pricing.json --silent
```

Output files are saved to `output/` as `<date>-<experiment_file>.json`.

---

## Checking results

Validate solution correctness with:

```bash
python3 checker/checker.py output/<output_file.json>
```

---

## Visualizing results

1. Open [https://gleraromero.github.io/kaleidoscope/networks2020](https://gleraromero.github.io/kaleidoscope/networks2020)
2. Upload the output JSON file.
3. Select experiments and attributes to display.

---

## Project structure

```
networks2020-/
├── code/            # C++ source code
│   ├── CMakeLists.txt
│   ├── goc/         # GOC optimization library (submodule)
│   ├── include/     # Project headers
│   └── src/         # Project source files
├── checker/         # Solution validator
├── experiments/     # Experiment definition files (JSON)
├── instances/       # Problem instance datasets
├── runner/          # Python experiment runner
│   ├── runner.py
│   └── config.json
├── output/          # Generated — experiment outputs (git-ignored)
├── .env.example     # Template for environment variables
├── setup_dev.sh     # Automated setup script
└── DEVELOPMENT.md   # This file
```

---

## Troubleshooting

**CMake error: `CPLEX_INCLUDE environment variable is not set`**
Run `source .env` before compiling, or re-run `bash setup_dev.sh`.

**`libboost_graph.a` not found after installing Boost**
The library may be at a different path. Find it with:
```bash
find /usr/lib -name "libboost_graph.a"
```
Then update `BOOST_BIN` in your `.env` file.

**Compilation errors related to C++14**
Ensure g++ >= 5 is installed: `g++ --version`. Upgrade with `sudo apt-get install g++`.
