#!/bin/sh
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
as=${AS:-msp430-elf-as}
out=${OUT:-"${TMPDIR:-/tmp}/idric-msp430-scalar.o"}
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/idric-e3m2.XXXXXX")
trap 'rm -rf "$tmpdir"' EXIT HUP INT TERM
tables="$tmpdir/e3m2_tables.inc"
combined="$tmpdir/scalar_formats_with_e3m2.S"
python3 "$script_dir/generate_e3m2_tables.py" > "$tables"
{
    cat "$script_dir/scalar_formats.S"
    printf '\n%s\n' '.section .rodata'
    cat "$tables"
} > "$combined"
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then cyan='\033[36m'; green='\033[32m'; red='\033[31m'; reset='\033[0m'; else cyan=''; green=''; red=''; reset=''; fi
printf '%b%s%b\n' "$cyan" 'MSP430 scalar assembly check' "$reset"
command -v "$as" >/dev/null 2>&1 || { printf '%bFAIL:%b MSP430 assembler not found: %s\n' "$red" "$reset" "$as" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { printf '%bFAIL:%b python3 not found\n' "$red" "$reset" >&2; exit 1; }
"$as" -o "$out" "$combined"
printf '%bPASS:%b base MSP430 source assembled: %s\n' "$green" "$reset" "$out"
