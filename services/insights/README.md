# node-goat-insights

A small Python (Flask) sidecar for the NodeGoat demo. Intentionally vulnerable.

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
