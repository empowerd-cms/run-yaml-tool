#!/usr/bin/env bash

set -euo pipefail

if ! command -v yq &> /dev/null; then
  echo "yq is required but not installed."
  exit 1
fi

if ! command -v jq &> /dev/null; then
  echo "jq is required but not installed."
  exit 1
fi

if [ $# -eq 0 ]; then
  echo "Usage: $0 <yaml-file>"
  exit 1
fi

YAML_FILE="$1"

if [ ! -f "$YAML_FILE" ]; then
  echo "File '$YAML_FILE' not found!"
  exit 1
fi

# Helper function: replace ${VAR} with env vars or print error if undefined
replace_env_vars() {
  local str="$1"
  while [[ "$str" =~ (\$\{([A-Za-z_][A-Za-z0-9_]*)\}) ]]; do
    var_name="${BASH_REMATCH[2]}"
    if [[ -z "${!var_name+x}" ]]; then
      echo "Environment variable '$var_name' is missing!" >&2
      exit 1
    fi
    str="${str//\$\{$var_name\}/${!var_name}}"
  done
  echo "$str"
}

# Get command name (top-level key in YAML)
CMD_NAME=$(yq e 'keys | .[0]' "$YAML_FILE")
CMD_ARGS=()

# Process flags if they exist
FLAGS_EXIST=$(yq e "has(\"$CMD_NAME\") and .${CMD_NAME} | has(\"flags\")" "$YAML_FILE")
if [ "$FLAGS_EXIST" = "true" ]; then
  for key in $(yq e ".${CMD_NAME}.flags | keys | .[]" "$YAML_FILE"); do
    type=$(yq e ".${CMD_NAME}.flags.\"$key\" | type" "$YAML_FILE")

    if [ "$type" = "!!seq" ]; then
      count=$(yq e ".${CMD_NAME}.flags.\"$key\" | length" "$YAML_FILE")
      for i in $(seq 0 $((count-1))); do
        item=$(yq e ".${CMD_NAME}.flags.\"$key\"[$i]" "$YAML_FILE")
        item=$(replace_env_vars "$item")
        [ ${#key} -eq 1 ] && CMD_ARGS+=("-$key" "$item") || CMD_ARGS+=("--$key" "$item")
      done
    else
      value=$(yq e ".${CMD_NAME}.flags.\"$key\"" "$YAML_FILE")
      [ "$value" == "null" ] && value=""
      value=$(replace_env_vars "$value")
      if [ -z "$value" ]; then
        [ ${#key} -eq 1 ] && CMD_ARGS+=("-$key") || CMD_ARGS+=("--$key")
      else
        [ ${#key} -eq 1 ] && CMD_ARGS+=("-$key" "$value") || CMD_ARGS+=("--$key" "$value")
      fi
    fi
  done
fi

# Process positional arguments if they exist
ARGS_EXIST=$(yq e "has(\"$CMD_NAME\") and .${CMD_NAME} | has(\"args\")" "$YAML_FILE")
if [ "$ARGS_EXIST" = "true" ]; then
  ARG_COUNT=$(yq e ".${CMD_NAME}.args | length" "$YAML_FILE")
  for i in $(seq 0 $((ARG_COUNT-1))); do
    arg=$(yq e ".${CMD_NAME}.args[$i]" "$YAML_FILE")
    arg=$(replace_env_vars "$arg")
    CMD_ARGS+=("$arg")
  done
fi

# Run the command and capture output
CMD_STR=("$CMD_NAME" "${CMD_ARGS[@]}")
OUTPUT=$("${CMD_STR[@]}")

# Check if output is valid JSON
if echo "$OUTPUT" | jq empty >/dev/null 2>&1; then
  jq -M -n --arg cmd "${CMD_STR[*]}" --argjson out "$OUTPUT" '{command: $cmd, output: $out}'
else
  jq -M -n --arg cmd "${CMD_STR[*]}" --arg out "$OUTPUT" '{command: $cmd, output: $out}'
fi

