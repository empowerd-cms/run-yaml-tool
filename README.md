# run-yaml-tool
Create Tools (for AI Agents) using YAML and Python 3.

`run-yaml-tool.py` is a utility script for executing commands defined in YAML files with support for environment variable interpolation. It makes it easy to define complex command invocations in YAML and run them safely with automatic error handling.

---

## Features

- Parse commands and arguments from a YAML file.
- Support for flags (`-f` / `--flag`) and positional arguments.
- Environment variable substitution in the form `${VAR_NAME}`.
  - Throws an error if a required environment variable is missing.
- Outputs command results in JSON format with the executed command and its output.
- Checks for required tools (`yq` and `jq`) before execution.
- Works with any command, not just `curl`.

---

## Basic Example

Create a YAML file called `nonce.yml`:

```yaml
curl:
  flags:
    s: ""
    b: "jwt_token_9511=${JWT_ENV}"
  args:
    - "http://localhost:9511/nonce"
````

Run the script with an environment variable:

```bash
export JWT_ENV="mysecretjwt"
./run-yaml-tool.py nonce.yml
```

Output:

```json
{
  "command": "curl -s -b jwt_token_9511=mysecretjwt http://localhost:9511/nonce",
  "output": "abcdef1234567890"
}
```

If the required environment variable is missing:

```text
Environment variable 'JWT_ENV' is missing!
```

### Example with Multiple Same Flags
```
# mailgun.yml
curl:
  flags:
    s: ""
    user: "api:[key]"
    F:
      - "from=Mailgun Sandbox <postmaster@[redacted].mailgun.org>"
      - "to=Neil <neil@[redacted]>"
      - "subject=Hello Neil"
      - "text=Congratulations Neil, you just sent an email with Mailgun! You are truly awesome!"
  args:
    - "https://api.mailgun.net/v3/[redacted].mailgun.org/messages"

```


---

## Notes

* The script automatically replaces `${VAR_NAME}` in flags and arguments with environment variables.
* If any required environment variable is missing, the script prints a descriptive error and exits.

---

## License

Apache2 License

