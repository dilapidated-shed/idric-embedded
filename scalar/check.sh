#!/bin/sh
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cc=${CC:-clang}
objdump=${OBJDUMP:-llvm-objdump}
out=${OUT:-"${TMPDIR:-/tmp}/idric-esp-rv32-scalar.o"}
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then cyan='\033[36m'; green='\033[32m'; red='\033[31m'; reset='\033[0m'; else cyan=''; green=''; red=''; reset=''; fi
printf '%b%s%b\n' "$cyan" 'ESP RV32IMC scalar assembly check' "$reset"
command -v "$cc" >/dev/null 2>&1 || { printf '%bFAIL:%b compiler not found: %s\n' "$red" "$reset" "$cc" >&2; exit 1; }
"$cc" --target=riscv32-none-elf -march=rv32imc -mabi=ilp32 -c "$script_dir/scalar_formats.S" -o "$out"
if command -v "$objdump" >/dev/null 2>&1; then "$objdump" -dr "$out" >/dev/null; fi
printf '%bPASS:%b RV32IMC source assembled: %s\n' "$green" "$reset" "$out"
