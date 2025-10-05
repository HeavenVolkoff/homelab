#!/usr/bin/env bash
#
# This script automates the process of building Fedora CoreOS Ignition files
# from a hierarchical Butane configuration structure.
#
# Workflow:
# 1. Finds all host-specific .yml files (any .yml not named base.yml).
# 2. For each host, it discovers all `base.yml` files in its parent directories.
# 3. It deep-merges the base files and the host file in the correct order
#    (from most general to most specific).
# 4. It processes any `'!!include path/to/file'` directives, inlining the
#    contents of the specified files.
# 5. It processes any `'!!env ENV_VAR'` directives, embedding the
#    value of the specified environment variable.
# 6. It transpiles the final Butane YAML into an Ignition JSON file.
#

set -euo pipefail

# Ensure the script runs from its own directory to handle relative paths correctly.
cd "$(cd "$(dirname "$0")" && pwd -P)"

# --- Configuration ---
TMPDIR="${TMPDIR:-/tmp}"
CONFIG_ROOT="configs"
OUTPUT_DIR="output"

# --- Function ---
has() {
  if [ $# -ne 1 ]; then
    echo "Usage: has <command>" >&2
    exit 1
  fi

  if ! command -v "$1" &>/dev/null; then
    echo "Error: Dependency '$1' is not installed. Please install it to continue." >&2
    exit 1
  fi
}

function join_by {
  local IFS="$1"
  shift
  echo "$*"
}

# --- Validation ---
has yq
has butane

# Create output directory
if [ -d "$OUTPUT_DIR" ]; then
  find "$OUTPUT_DIR" -type f \( -name "*.bu" -o -name "*.ign" \) -delete
  rmdir "$OUTPUT_DIR" 2>/dev/null || true
elif [ -e "$OUTPUT_DIR" ]; then
  echo "Error: '$OUTPUT_DIR' exists and is not a directory. Please remove or rename it." >&2
  exit 1
fi
mkdir -p "$OUTPUT_DIR"

echo "--- Starting Butane build process ---"

while read -r host_file; do
  host_name=$(basename "$host_file" .yml)

  echo
  echo "==> Processing host: $host_name"

  # Discover hierarchical base files
  merge_list=()
  current_dir=$(dirname "$host_file")
  # Walk up from the host's directory to the config root
  while [[ "$current_dir" != "$CONFIG_ROOT" && "$current_dir" != "." && "$current_dir" != "/" ]]; do
    if [[ -f "$current_dir/base.yml" ]]; then
      # Prepend to the list to ensure correct merge order (general -> specific)
      merge_list=("$current_dir/base.yml" "${merge_list[@]}")
    fi
    current_dir=$(dirname "$current_dir")
  done

  # Check the root config directory to ensure it's first in the merge list
  if [[ -f "$CONFIG_ROOT/base.yml" ]]; then
    merge_list=("$CONFIG_ROOT/base.yml" "${merge_list[@]}")
  fi

  # Add the host file itself as the final, most specific layer
  merge_list+=("$host_file")

  echo "  - Merge order: ${merge_list[*]}"
  temp_bu_file="$(mktemp "${TMPDIR}/butane.XXXXXX")"
  trap 'rm -f "$temp_bu_file"' EXIT
  # Use '*+' for a deep merge that concatenates arrays
  yq eval-all '. as $item ireduce ({}; . *+ $item)' "${merge_list[@]}" >"$temp_bu_file"

  echo "  - Inlining external files..."
  while read -r include; do
    IFS=";" read -r -a filepaths <<<"$(echo "$include" | sed 's/^!!include //')"

    load_str=()
    for filepath in "${filepaths[@]}"; do
      if ! [ -f "$filepath" ]; then
        echo "Warning: file $filepath not found, skipping" >&2
        continue
      fi
      load_str+=("load_str(\"$filepath\")")
    done

    if [ ${#load_str[@]} -eq 0 ]; then
      echo "Warning: no valid files found for include directive '$include', skipping" >&2
      continue
    fi

    include_expr=$(join_by + "${load_str[@]}")
    yq eval-all -i "(.. | select(. == \"$include\")) |= ( $include_expr )" "$temp_bu_file"
  done < <(yq -r '.. | select(tag == "!!str") | select(test("^!!include "))' "$temp_bu_file")

  echo "  - Inlining environment variables..."
  while read -r envvar; do
    envname="$(echo "$envvar" | sed 's/^!!env //')"
    yq eval-all -i "(.. | select(. == \"$envvar\")) |= env($envname)" "$temp_bu_file"
  done < <(yq -r '.. | select(tag == "!!str") | select(test("^!!env "))' "$temp_bu_file")

  yq -i 'with(.. | select(tag == "!!str"); . style="literal")' "$temp_bu_file"
  yq -i '... style=""' "$temp_bu_file"

  final_bu_file="${OUTPUT_DIR}/${host_name}.bu"
  if [[ "$-" == *x* ]]; then
    cp "$temp_bu_file" "$final_bu_file"
  else
    final_bu_file="$temp_bu_file"
  fi

  echo "  - Generated final Butane YAML: $final_bu_file"
  final_ign_file="${OUTPUT_DIR}/${host_name}.ign"

  echo "  - Transpiling to Ignition: $final_ign_file"
  butane --pretty --strict "$final_bu_file" >"$final_ign_file"
done < <(find "$CONFIG_ROOT" -type f -name "*.yml" -not -name "base.yml")

echo
echo "--- Build process complete! ---"
echo "Final Ignition files are located in the '${OUTPUT_DIR}' directory."
