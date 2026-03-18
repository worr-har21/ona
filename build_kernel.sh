#!/usr/bin/env bash
set -e

KERNEL_DIR="/workspaces/ona/kernel"
LOG="/workspaces/ona/build.log"
OUT="/workspaces/ona/out"

mkdir -p "$OUT"

cd "$KERNEL_DIR"

export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export CC=clang-18
export LLVM=1
export LLVM_IAS=1

echo "[$(date)] Starting kernel build..." | tee "$LOG"

make -j$(nproc) Image.gz 2>&1 | tee -a "$LOG"

if [ -f arch/arm64/boot/Image.gz ]; then
    cp arch/arm64/boot/Image.gz "$OUT/Image.gz"
    echo "[$(date)] Build SUCCESS: $OUT/Image.gz" | tee -a "$LOG"
else
    echo "[$(date)] Build FAILED - check $LOG" | tee -a "$LOG"
    exit 1
fi
