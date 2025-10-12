#!/usr/bin/env bash

#
# Parses LABEL directives from a Containerfile.
#
# This function reads a given Containerfile and extracts all key-value pairs
# from single and multi-line LABEL instructions.
#
# @param {string} $1 - The path to the Containerfile to parse.
# @output            - Prints each label as a 'key="value"' string on a new line.
# @return {number} 0 on success, 1 on error (e.g., file not found).
#
function parse_containerfile_labels() {
  local file_path="$1"
  if [[ ! -f "$file_path" ]]; then
    echo "Error: File not found at '$file_path'" >&2
    return 1
  fi

  # Step 1: Consolidate all multi-line LABEL directives into single lines.
  # 1. `sed ...` joins all lines ending in '\' with the next line.
  # 2. `grep ...` filters the result to only include lines starting with 'LABEL'.
  # 3. `sed ...` removes the 'LABEL ' keyword prefix from those lines.
  local consolidated_labels
  consolidated_labels=$(
    sed -e ':a' -e 'N' -e '$!ba' -e 's/\\\n\s*/ /g' "$file_path" \
      | grep '^\s*LABEL' | sed 's/^\s*LABEL\s*//'
  )

  # Step 2: Parse the consolidated string of labels into key=value pairs.
  local -a parsed_labels=()
  local pair_regex='([a-zA-Z0-9_.-]+)=("([^"]*)"|'\''([^'\'']*)'\''|([^[:space:]]+))'
  while [[ "$consolidated_labels" =~ $pair_regex ]]; do
    local key="${BASH_REMATCH[1]}"
    local value
    if [ -n "${BASH_REMATCH[3]}" ]; then
      value="${BASH_REMATCH[3]}" # Content of double quotes
    elif [ -n "${BASH_REMATCH[4]}" ]; then
      value="${BASH_REMATCH[4]}" # Content of single quotes
    else
      value="${BASH_REMATCH[5]}" # Unquoted value
    fi

    parsed_labels+=("${key}=${value}")

    consolidated_labels="${consolidated_labels#*"${BASH_REMATCH[0]}"}"
  done

  if ((${#parsed_labels[@]} > 0)); then
    printf "%s\n" "${parsed_labels[@]}"
  fi
}

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <Containerfile>" >&2
  exit 1
fi

parse_containerfile_labels "$1"
