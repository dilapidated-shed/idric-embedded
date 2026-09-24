#!/bin/sh
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
as=${AS:-msp430-elf-as}
out=${OUT:-"${TMPDIR:-/tmp}/idric-msp430-scalar.o"}
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then cyan='\033[36m'; green='\033[32m'; red='\033[31m'; reset='\033[0m'; else cyan=''; green=''; red=''; reset=''; fi
printf '%b%s%b\n' "$cyan" 'MSP430 scalar assembly check' "$reset"
command -v "$as" >/dev/null 2>&1 || { printf '%bFAIL:%b MSP430 assembler not found: %s\n' "$red" "$reset" "$as" >&2; exit 1; }
"$as" -o "$out" "$script_dir/scalar_formats.S"
printf '%bPASS:%b base MSP430 source assembled: %s\n' "$green" "$reset" "$out"
