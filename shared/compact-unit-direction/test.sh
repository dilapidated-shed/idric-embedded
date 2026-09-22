#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
build_dir="${TMPDIR:-/tmp}/idric-compact-unit-direction"
mkdir -p "$build_dir"

cc -std=c17 -O2 -Wall -Wextra -Werror -Wpedantic -Wshadow \
  -I"$script_dir" \
  "$script_dir/compact_unit_direction_test.c" \
  -lm \
  -o "$build_dir/compact-unit-direction-test"

"$build_dir/compact-unit-direction-test"
