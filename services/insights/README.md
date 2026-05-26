# node-goat-insights

A small Python (Flask) sidecar for the NodeGoat demo. Intentionally vulnerable;
exists so the JFrog platform demo includes a second package ecosystem (PyPI)
alongside npm and Docker.

## What this surfaces in a JFrog scan

- **Xray SCA** — pinned vulnerable versions of Flask, requests, urllib3, PyYAML, Jinja2, Werkzeug, itsdangerous, cryptography, paramiko, pyjwt, lxml.
- **JAS Secrets** — hardcoded AWS keys, GitHub PAT, Slack webhook, JWT secret in `insights/config.py`.
- **JAS SAST** — SSRF, command injection, SSTI, XXE, insecure deserialization, unsafe `yaml.load`.
- **JAS Contextual Analysis** — many CVEs in the deps are *applicable* because the vulnerable APIs are actually called.

## Local run (for testing only)

```sh
pip install -r requirements.txt
python -m insights.app
```

## Demo endpoints

| Endpoint | Vuln |
|---|---|
| `/fetch?url=...` | SSRF |
| `/parse-config` (POST yaml body) | Unsafe deserialization |
| `/render?name=...` | SSTI |
| `/run?cmd=...` | Command injection |
| `/parse-xml` (POST xml body) | XXE |
| `/deserialize` (POST base64 pickle) | Pickle deserialization |
| `/token?user=...` | Hardcoded JWT signing key |
