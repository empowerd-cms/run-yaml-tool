#!/usr/bin/env python3
import sys
import os
import json
import subprocess
import yaml


def replace_env_vars(value: str) -> str:
    """Replace ${VAR} with environment variables or fail if undefined."""
    out = ""
    i = 0
    while i < len(value):
        if value[i:i+2] == "${":
            j = value.find("}", i+2)
            if j == -1:
                raise ValueError(f"Unclosed environment variable in: {value}")
            var_name = value[i+2:j]
            if var_name not in os.environ:
                sys.stderr.write(f"Environment variable '{var_name}' is missing!\n")
                sys.exit(1)
            out += os.environ[var_name]
            i = j + 1
        else:
            out += value[i]
            i += 1
    return out


def build_command(yaml_data: dict):
    """Convert YAML structure into command and arguments list."""
    if len(yaml_data) != 1:
        sys.stderr.write("YAML must contain exactly one top-level command.\n")
        sys.exit(1)

    cmd_name = next(iter(yaml_data))
    cmd_spec = yaml_data[cmd_name]
    args = [cmd_name]

    # Process flags
    if "flags" in cmd_spec:
        for key, val in cmd_spec["flags"].items():
            if isinstance(val, list):
                for item in val:
                    item = replace_env_vars(str(item))
                    if len(key) == 1:
                        args.extend([f"-{key}", item])
                    else:
                        args.extend([f"--{key}", item])
            else:
                if val is None:
                    val = ""
                val = replace_env_vars(str(val))
                if val == "":
                    args.append(f"-{key}" if len(key) == 1 else f"--{key}")
                else:
                    if len(key) == 1:
                        args.extend([f"-{key}", val])
                    else:
                        args.extend([f"--{key}", val])

    # Process positional args
    if "args" in cmd_spec:
        for item in cmd_spec["args"]:
            args.append(replace_env_vars(str(item)))

    return args


def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <yaml-file>")
        sys.exit(1)

    yaml_file = sys.argv[1]
    if not os.path.isfile(yaml_file):
        print(f"File '{yaml_file}' not found!")
        sys.exit(1)

    with open(yaml_file, "r") as f:
        yaml_data = yaml.safe_load(f)

    cmd = build_command(yaml_data)

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    except FileNotFoundError:
        print(f"Command '{cmd[0]}' not found.")
        sys.exit(1)

    stdout = result.stdout.strip()
    stderr = result.stderr.strip()

    # Detect JSON output
    try:
        parsed = json.loads(stdout)
        print(json.dumps({"command": cmd, "output": parsed}, indent=2))
    except json.JSONDecodeError:
        print(json.dumps({"command": cmd, "output": stdout, "error": stderr}, indent=2))


if __name__ == "__main__":
    main()

