#!/bin/bash
# Script to compare MAC loop vs baseline loop using gem5 (O3 CPU)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RISCV_TEST_DIR="$SCRIPT_DIR/../riscv_test"
GEM5_BIN="$SCRIPT_DIR/build/RISCV/gem5.opt"
MAC_OUTDIR="m5out_mac_loop"
BASE_OUTDIR="m5out_baseline_loop"
N_ITER=1000

echo "========================================"
echo "MAC Loop Instruction Comparison Test"
echo "========================================"
echo ""

if [ ! -x "$GEM5_BIN" ]; then
    echo "ERROR: gem5 binary not found at $GEM5_BIN"
    echo "Please build gem5 first."
    exit 1
fi

echo "Step 1: Compiling loop test programs..."
echo "--------------------------------------"

cd "$RISCV_TEST_DIR"

if command -v riscv64-linux-gnu-gcc &> /dev/null; then
    RISCV_GCC="riscv64-linux-gnu-gcc"
    RISCV_FLAGS="-march=rv64imafdc -mabi=lp64d"
elif command -v riscv64-unknown-elf-gcc &> /dev/null; then
    RISCV_GCC="riscv64-unknown-elf-gcc"
    RISCV_FLAGS="-march=rv64i -mabi=lp64"
else
    echo "ERROR: RISC-V cross compiler not found."
    exit 1
fi

echo "Using toolchain: $RISCV_GCC"

$RISCV_GCC $RISCV_FLAGS -O2 -static -o test_mac_loop test_mac_loop.c
echo "✓ test_mac_loop compiled"

$RISCV_GCC $RISCV_FLAGS -O2 -static -o test_baseline_loop test_baseline_loop.c
echo "✓ test_baseline_loop compiled"

echo ""

cd "$SCRIPT_DIR"
rm -rf "$MAC_OUTDIR" "$BASE_OUTDIR"

log_mac=mac_loop_output.log
log_base=baseline_loop_output.log

echo "Step 2: gemRunning 5 simulations (O3 CPU)..."
echo "--------------------------------------"
$GEM5_BIN --outdir="$MAC_OUTDIR" configs/tutorial/riscv_mac_loop_test_o3.py > "$log_mac" 2>&1
echo "✓ MAC loop simulation complete"

$GEM5_BIN --outdir="$BASE_OUTDIR" configs/tutorial/riscv_baseline_loop_test_o3.py > "$log_base" 2>&1
echo "✓ Baseline loop simulation complete"

echo ""
echo "========================================"
echo "RESULT SUMMARY"
echo "========================================"

echo "--- Program Output ---"
if grep -q "PASSED" "$log_mac"; then
    grep -E "(result|Expected|PASSED|FAILED)" "$log_mac"
else
    echo "MAC loop output not found"
fi

echo ""
if grep -q "PASSED" "$log_base"; then
    grep -E "(result|Expected|PASSED|FAILED)" "$log_base"
else
    echo "Baseline loop output not found"
fi

echo ""

stat() {
    local file=$1
    local key=$2
    grep "^$key" "$file" | awk '{print $2}'
}

mac_ticks=$(stat "$MAC_OUTDIR/stats.txt" simTicks)
base_ticks=$(stat "$BASE_OUTDIR/stats.txt" simTicks)
mac_insts=$(stat "$MAC_OUTDIR/stats.txt" simInsts)
base_insts=$(stat "$BASE_OUTDIR/stats.txt" simInsts)
mac_cycles=$(stat "$MAC_OUTDIR/stats.txt" board.processor.cores.core.numCycles)
base_cycles=$(stat "$BASE_OUTDIR/stats.txt" board.processor.cores.core.numCycles)

mac_ipc="N/A"
base_ipc="N/A"
if [ -n "$mac_insts" ] && [ -n "$mac_cycles" ] && [ "$mac_cycles" != 0 ]; then
    mac_ipc=$(echo "scale=4; $mac_insts / $mac_cycles" | bc)
fi
if [ -n "$base_insts" ] && [ -n "$base_cycles" ] && [ "$base_cycles" != 0 ]; then
    base_ipc=$(echo "scale=4; $base_insts / $base_cycles" | bc)
fi

insts_per_mac="N/A"
if [ -n "$mac_insts" ]; then
    insts_per_mac=$(echo "scale=2; $mac_insts / $N_ITER" | bc)
fi
insts_per_baseline="N/A"
if [ -n "$base_insts" ]; then
    insts_per_baseline=$(echo "scale=2; $base_insts / $N_ITER" | bc)
fi

diff_ticks=$(echo "$base_ticks - $mac_ticks" | bc)
diff_cycles=$(echo "$base_cycles - $mac_cycles" | bc)
diff_insts=$(echo "$base_insts - $mac_insts" | bc)

speedup="N/A"
if [ "$base_ticks" -gt 0 ]; then
    speedup=$(echo "scale=2; ($base_ticks - $mac_ticks) * 100 / $base_ticks" | bc)
fi

if [[ $speedup == -* ]]; then
    speed_note="MAC is ${speedup#-}% slower than baseline"
else
    speed_note="MAC is $speedup% faster than baseline"
fi

echo "--- Performance Metrics ---"
printf "%-28s | %-12s | %-12s | %-12s\n" "Metric" "MAC" "Baseline" "Difference"
printf "%-28s | %-12s | %-12s | %-12s\n" "----------------------------" "------------" "------------" "------------"
printf "%-28s | %-12s | %-12s | %-12s\n" "simTicks" "$mac_ticks" "$base_ticks" "$diff_ticks"
printf "%-28s | %-12s | %-12s | %-12s\n" "numCycles" "$mac_cycles" "$base_cycles" "$diff_cycles"
printf "%-28s | %-12s | %-12s | %-12s\n" "simInsts" "$mac_insts" "$base_insts" "$diff_insts"
printf "%-28s | %-12s | %-12s | %-12s\n" "IPC" "$mac_ipc" "$base_ipc" "--"
printf "%-28s | %-12s | %-12s | %-12s\n" "Insts per iteration" "$insts_per_mac" "$insts_per_baseline" "--"

echo ""
echo "Performance summary: $speed_note"
echo ""
echo "Artifacts saved in:"
echo "  MAC loop:      $MAC_OUTDIR/"
echo "  Baseline loop: $BASE_OUTDIR/"
echo "  Logs:          $log_mac, $log_base"
echo ""
echo "To inspect stats:"
echo "  less $MAC_OUTDIR/stats.txt"
echo "  less $BASE_OUTDIR/stats.txt"
echo ""
