#!/usr/bin/env bash
set -euo pipefail

quotes_file="$1"
state_file="${XDG_RUNTIME_DIR:-/tmp}/eww-quote-index"

# Initialize state if missing
if [[ ! -f "$state_file" ]]; then
    echo 0 > "$state_file"
fi

total_lines=$(wc -l < "$quotes_file")
current_index=$(cat "$state_file")

# Get the line (1-based for sed)
line_num=$((current_index + 1))
sed -n "${line_num}p" "$quotes_file"

# Advance and wrap
next_index=$(((current_index + 1) % total_lines))
echo "$next_index" > "$state_file"
