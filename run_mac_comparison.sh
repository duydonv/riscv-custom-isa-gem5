# Script to compile, run, and compare MAC instruction vs baseline

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RISCV_TEST_DIR="$SCRIPT_DIR/../riscv_test"
GEM5_BIN="$SCRIPT_DIR/build/RISCV/gem5.opt"

echo "========================================"
echo "MAC Instruction Comparison Test"
echo "========================================"
echo ""

# Check if gem5 is built
if [ ! -f "$GEM5_BIN" ]; then
    echo "ERROR: gem5 not found at $GEM5_BIN"
    echo "Please build gem5 first:"
    echo "  cd $SCRIPT_DIR"
    echo "  python3 \$(which scons) build/RISCV/gem5.opt -j\$(nproc)"
    exit 1
fi

# Step 1: Compile test programs
echo "Step 1: Compiling test programs..."
echo "--------------------------------------"

cd "$RISCV_TEST_DIR"

# Check if RISC-V toolchain is available
if command -v riscv64-linux-gnu-gcc &> /dev/null; then
    RISCV_GCC="riscv64-linux-gnu-gcc"
    RISCV_FLAGS="-march=rv64imafdc -mabi=lp64d"
elif command -v riscv64-unknown-elf-gcc &> /dev/null; then
    RISCV_GCC="riscv64-unknown-elf-gcc"
    RISCV_FLAGS="-march=rv64i -mabi=lp64"
else
    echo "ERROR: RISC-V toolchain not found"
    echo "Please install riscv64-linux-gnu-gcc or riscv64-unknown-elf-gcc"
    exit 1
fi

echo "Using RISC-V toolchain: $RISCV_GCC"

# Compile MAC test
echo "Compiling test_mac.c..."
$RISCV_GCC $RISCV_FLAGS -static -o test_mac test_mac.c
echo "✓ test_mac compiled"

# Compile baseline test
echo "Compiling test_baseline.c..."
$RISCV_GCC $RISCV_FLAGS -static -o test_baseline test_baseline.c
echo "✓ test_baseline compiled"

echo ""

# Step 2: Verify instruction encoding
echo "Step 2: Verifying instruction encoding..."
echo "--------------------------------------"
echo "MAC instruction encoding:"
if command -v riscv64-linux-gnu-objdump &> /dev/null; then
    riscv64-linux-gnu-objdump -d test_mac | grep -A 2 ".insn" || true
elif command -v riscv64-unknown-elf-objdump &> /dev/null; then
    riscv64-unknown-elf-objdump -d test_mac | grep -A 2 ".insn" || true
fi
echo ""

# Step 3: Run MAC test
echo "Step 3: Running MAC instruction test..."
echo "--------------------------------------"
cd "$SCRIPT_DIR"
$GEM5_BIN --outdir=m5out_mac configs/tutorial/riscv_mac_test.py > mac_output.log 2>&1
echo "✓ MAC test completed"

# Step 4: Run baseline test
echo "Step 4: Running baseline test (MUL + ADD)..."
echo "--------------------------------------"
$GEM5_BIN --outdir=m5out_baseline configs/tutorial/riscv_baseline_test.py > baseline_output.log 2>&1
echo "✓ Baseline test completed"
echo ""

# Step 5: Compare results
echo "========================================"
echo "COMPARISON RESULTS"
echo "========================================"
echo ""

# Extract and display program output
echo "--- Program Output ---"
echo ""
echo "MAC Test Output:"
grep -A 20 "MAC Instruction Test" mac_output.log | grep -E "(Result:|PASSED|FAILED)" || echo "MAC test output not found"
echo ""

echo "Baseline Test Output:"
grep -A 20 "Baseline Test" baseline_output.log | grep -E "(Result:|PASSED|FAILED)" || echo "Baseline test output not found"
echo ""

# Extract and compare statistics
echo "--- Performance Statistics ---"
echo ""

# Function to extract stat
extract_stat() {
    local file=$1
    local stat=$2
    grep "^$stat " "$file" | awk '{print $2}'
}

if [ -f "m5out_mac/stats.txt" ] && [ -f "m5out_baseline/stats.txt" ]; then
    echo "Metric                    | MAC Test    | Baseline    | Difference"
    echo "--------------------------|-------------|-------------|------------"

    # Simulation ticks
    mac_ticks=$(extract_stat "m5out_mac/stats.txt" "simTicks")
    base_ticks=$(extract_stat "m5out_baseline/stats.txt" "simTicks")
    if [ -n "$mac_ticks" ] && [ -n "$base_ticks" ]; then
        diff_ticks=$((base_ticks - mac_ticks))
        echo "Simulation Ticks          | $mac_ticks | $base_ticks | $diff_ticks"
    fi

    # Simulated instructions
    mac_insts=$(extract_stat "m5out_mac/stats.txt" "simInsts")
    base_insts=$(extract_stat "m5out_baseline/stats.txt" "simInsts")
    if [ -n "$mac_insts" ] && [ -n "$base_insts" ]; then
        diff_insts=$((base_insts - mac_insts))
        echo "Instructions Executed     | $mac_insts | $base_insts | $diff_insts"
    fi

    # CPU cycles
    mac_cycles=$(extract_stat "m5out_mac/stats.txt" "board.processor.cores.core.numCycles" || echo "N/A")
    base_cycles=$(extract_stat "m5out_baseline/stats.txt" "board.processor.cores.core.numCycles" || echo "N/A")
    if [ "$mac_cycles" != "N/A" ] && [ "$base_cycles" != "N/A" ]; then
        diff_cycles=$((base_cycles - mac_cycles))
        echo "CPU Cycles                | $mac_cycles | $base_cycles | $diff_cycles"
    fi

    echo ""

    if [ -n "$mac_ticks" ] && [ -n "$base_ticks" ] && [ "$base_ticks" -gt 0 ]; then
        speedup=$(echo "scale=2; ($base_ticks - $mac_ticks) * 100 / $base_ticks" | bc)
        if [ "${speedup:0:1}" = "-" ]; then
            echo "Performance: MAC is ${speedup#-}% SLOWER than baseline"
            echo "(This is expected for single instruction due to overhead)"
        else
            echo "Performance: MAC is $speedup% FASTER than baseline"
        fi
    fi
else
    echo "ERROR: Could not find stats.txt files"
fi

echo ""
echo "========================================"
echo "Test Complete!"
echo "========================================"
echo ""
echo "Detailed results:"
echo "  MAC test:      m5out_mac/"
echo "  Baseline test: m5out_baseline/"
echo ""
echo "View detailed stats:"
echo "  cat m5out_mac/stats.txt"
echo "  cat m5out_baseline/stats.txt"
echo ""
