#!/usr/bin/env bash
# Setup script for the networks2020 local development environment.
# Usage: bash setup_dev.sh [--cplex-include PATH] [--cplex-bin PATH]

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
CPLEX_INCLUDE_ARG=""
CPLEX_BIN_ARG=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --cplex-include) CPLEX_INCLUDE_ARG="$2"; shift 2 ;;
        --cplex-bin)     CPLEX_BIN_ARG="$2";     shift 2 ;;
        -h|--help)
            echo "Usage: bash setup_dev.sh [--cplex-include PATH] [--cplex-bin PATH]"
            echo ""
            echo "Options:"
            echo "  --cplex-include PATH   Path to CPLEX include directory"
            echo "  --cplex-bin     PATH   Path to CPLEX static library (.a)"
            echo ""
            echo "If CPLEX paths are not provided, the script will try to detect them"
            echo "from existing CPLEX_INCLUDE / CPLEX_BIN environment variables."
            exit 0
            ;;
        *) error "Unknown argument: $1"; exit 1 ;;
    esac
done

# ---------------------------------------------------------------------------
# 1. Check Python version
# ---------------------------------------------------------------------------
info "Checking Python version..."
if command -v python3 &>/dev/null; then
    PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    PYTHON_MAJOR=$(echo "$PYTHON_VERSION" | cut -d. -f1)
    PYTHON_MINOR=$(echo "$PYTHON_VERSION" | cut -d. -f2)
    if [[ "$PYTHON_MAJOR" -ge 3 && "$PYTHON_MINOR" -ge 6 ]]; then
        success "Python $PYTHON_VERSION found."
    else
        error "Python >= 3.6 is required (found $PYTHON_VERSION). Please upgrade."
        exit 1
    fi
else
    error "python3 not found. Please install Python >= 3.6."
    exit 1
fi

# ---------------------------------------------------------------------------
# 2. Check CMake
# ---------------------------------------------------------------------------
info "Checking CMake..."
if command -v cmake &>/dev/null; then
    CMAKE_VERSION=$(cmake --version | head -1 | awk '{print $3}')
    success "CMake $CMAKE_VERSION found."
else
    warn "CMake not found. Attempting to install..."
    if command -v apt-get &>/dev/null; then
        sudo apt-get update -qq && sudo apt-get install -y cmake
        success "CMake installed."
    else
        error "CMake not found and automatic installation is not supported on this OS."
        error "Please install CMake >= 2.8.4 manually: https://cmake.org/"
        exit 1
    fi
fi

# ---------------------------------------------------------------------------
# 3. Check C++14 compiler
# ---------------------------------------------------------------------------
info "Checking C++ compiler..."
if command -v g++ &>/dev/null; then
    GCC_VERSION=$(g++ -dumpfullversion -dumpversion 2>/dev/null || g++ --version | head -1 | grep -oP '\d+\.\d+\.\d+')
    success "g++ $GCC_VERSION found."
else
    warn "g++ not found. Attempting to install build-essential..."
    if command -v apt-get &>/dev/null; then
        sudo apt-get update -qq && sudo apt-get install -y build-essential
        success "build-essential installed."
    else
        error "g++ not found. Please install a C++14-compatible compiler."
        exit 1
    fi
fi

# ---------------------------------------------------------------------------
# 4. Install Boost Graph Library
# ---------------------------------------------------------------------------
info "Checking Boost Graph Library..."
if [[ -f /usr/include/boost/graph/adjacency_list.hpp ]]; then
    success "Boost Graph Library found at /usr/include/boost."
else
    warn "Boost Graph Library not found. Attempting to install..."
    if command -v apt-get &>/dev/null; then
        sudo apt-get update -qq && sudo apt-get install -y libboost-all-dev
        success "Boost libraries installed."
    else
        error "Boost Graph Library not found and automatic installation is not supported."
        error "Please install Boost >= 1.66: https://www.boost.org/"
        exit 1
    fi
fi

BOOST_INCLUDE_DETECTED="/usr/include"
BOOST_BIN_DETECTED=$(find /usr/lib -name "libboost_graph.a" 2>/dev/null | head -1)
if [[ -z "$BOOST_BIN_DETECTED" ]]; then
    # Fallback: try shared library path for linking
    BOOST_BIN_DETECTED=$(find /usr/lib -name "libboost_graph.so" 2>/dev/null | head -1)
fi

if [[ -n "$BOOST_BIN_DETECTED" ]]; then
    success "Boost library detected: $BOOST_BIN_DETECTED"
else
    warn "Could not auto-detect Boost library binary. You may need to set BOOST_BIN manually."
fi

# ---------------------------------------------------------------------------
# 5. Resolve CPLEX paths
# ---------------------------------------------------------------------------
info "Checking CPLEX..."

CPLEX_INCLUDE_FINAL="${CPLEX_INCLUDE_ARG:-${CPLEX_INCLUDE:-}}"
CPLEX_BIN_FINAL="${CPLEX_BIN_ARG:-${CPLEX_BIN:-}}"

if [[ -z "$CPLEX_INCLUDE_FINAL" || -z "$CPLEX_BIN_FINAL" ]]; then
    # Try to auto-detect a CPLEX installation
    for dir in /opt/ibm/ILOG /opt/cplex; do
        if [[ -d "$dir" ]]; then
            CPLEX_STUDIO=$(find "$dir" -maxdepth 1 -type d -name "CPLEX_Studio*" | sort | tail -1)
            if [[ -n "$CPLEX_STUDIO" ]]; then
                CPLEX_INCLUDE_FINAL="${CPLEX_STUDIO}/cplex/include"
                CPLEX_BIN_FINAL=$(find "${CPLEX_STUDIO}/cplex/lib" -name "libcplex.a" 2>/dev/null | head -1)
                break
            fi
        fi
    done
fi

CPLEX_OK=false
if [[ -n "$CPLEX_INCLUDE_FINAL" && -d "$CPLEX_INCLUDE_FINAL" ]] && \
   [[ -n "$CPLEX_BIN_FINAL"    && -f "$CPLEX_BIN_FINAL"    ]]; then
    success "CPLEX found."
    success "  CPLEX_INCLUDE = $CPLEX_INCLUDE_FINAL"
    success "  CPLEX_BIN     = $CPLEX_BIN_FINAL"
    CPLEX_OK=true
else
    warn "CPLEX not found or incomplete paths."
    warn "CPLEX is required to compile the solver. You can obtain it from:"
    warn "  https://www.ibm.com/products/ilog-cplex-optimization-studio"
    warn "Once installed, re-run this script with:"
    warn "  bash setup_dev.sh --cplex-include <path> --cplex-bin <path>"
    warn "Or set the environment variables before running:"
    warn "  export CPLEX_INCLUDE=<path_to_cplex_include>"
    warn "  export CPLEX_BIN=<path_to_libcplex.a>"
fi

# ---------------------------------------------------------------------------
# 6. Create / update .env file with environment variables
# ---------------------------------------------------------------------------
ENV_FILE="$REPO_DIR/.env"
info "Writing environment variables to $ENV_FILE..."

cat > "$ENV_FILE" <<EOF
# Auto-generated by setup_dev.sh — $(date)
# Source this file before compiling: source .env

export BOOST_INCLUDE="${BOOST_INCLUDE_DETECTED}"
export BOOST_BIN="${BOOST_BIN_DETECTED}"
export CPLEX_INCLUDE="${CPLEX_INCLUDE_FINAL}"
export CPLEX_BIN="${CPLEX_BIN_FINAL}"
EOF

success ".env file written."

# ---------------------------------------------------------------------------
# 7. Create output directory (required by runner)
# ---------------------------------------------------------------------------
OUTPUT_DIR="$REPO_DIR/output"
if [[ ! -d "$OUTPUT_DIR" ]]; then
    mkdir -p "$OUTPUT_DIR"
    success "Created output directory: $OUTPUT_DIR"
else
    success "Output directory already exists: $OUTPUT_DIR"
fi

# ---------------------------------------------------------------------------
# 8. Summary
# ---------------------------------------------------------------------------
echo ""
echo "============================================================"
echo " Development environment setup complete"
echo "============================================================"
echo ""
echo "Next steps:"
echo ""
echo "  1. Source the environment variables:"
echo "     source $ENV_FILE"
echo ""
if [[ "$CPLEX_OK" = false ]]; then
echo "  2. Install CPLEX and re-run setup:"
echo "     bash setup_dev.sh --cplex-include <path> --cplex-bin <path>"
echo "     Then source .env again."
echo ""
fi
echo "  3. Run an experiment:"
echo "     python3 runner/runner.py experiments/pricing.json"
echo ""
echo "  4. Check results with the checker:"
echo "     python3 checker/checker.py output/<output_file.json>"
echo ""
