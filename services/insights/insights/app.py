"""
NodeGoat Insights sidecar.

DEMO ONLY: Contains intentional vulnerabilities to demo JFrog
Xray + JAS (SAST, Secrets, Contextual Analysis). Do not deploy.
"""

import os
import subprocess
import pickle
import base64

import requests
import yaml
import jwt
from flask import Flask, request, jsonify, render_template_string
from lxml import etree

from . import config

app = Flask(__name__)


@app.route("/healthz")
def healthz():
    return jsonify({"status": "ok"})


@app.route("/fetch")
def fetch_url():
    """SSRF: user-controlled URL passed directly to requests.get."""
    url = request.args.get("url", "")
    resp = requests.get(url, verify=False, timeout=5)
    return resp.text, resp.status_code


@app.route("/parse-config", methods=["POST"])
def parse_config():
    """Unsafe yaml.load — allows arbitrary Python object construction."""
    raw = request.data
    parsed = yaml.load(raw)
    return jsonify({"parsed": str(parsed)})


@app.route("/render")
def render():
    """SSTI: user input rendered as a Jinja2 template."""
    name = request.args.get("name", "world")
    template = "<h1>Hello %s</h1>" % name
    return render_template_string(template)


@app.route("/run")
def run_cmd():
    """Command injection: shell=True with user input."""
    cmd = request.args.get("cmd", "echo hi")
    out = subprocess.check_output(cmd, shell=True)
    return out


@app.route("/parse-xml", methods=["POST"])
def parse_xml():
    """XXE: lxml parser with external entity resolution enabled."""
    parser = etree.XMLParser(resolve_entities=True, no_network=False)
    tree = etree.fromstring(request.data, parser)
    return etree.tostring(tree)


@app.route("/deserialize", methods=["POST"])
def deserialize():
    """Insecure deserialization via pickle."""
    blob = base64.b64decode(request.data)
    obj = pickle.loads(blob)
    return jsonify({"obj": str(obj)})


@app.route("/token")
def issue_token():
    """Signs a JWT using a hardcoded secret."""
    payload = {"user": request.args.get("user", "anonymous")}
    token = jwt.encode(payload, config.JWT_SECRET, algorithm="HS256")
    return jsonify({"token": token})


@app.route("/upstream")
def upstream():
    """Pulls aggregate stats from the node-goat app."""
    r = requests.get(
        config.UPSTREAM_NODE_GOAT_URL + "/dashboard",
        verify=False,
        timeout=5,
    )
    return r.text, r.status_code


def main():
    port = int(os.environ.get("PORT", "5000"))
    app.run(host="0.0.0.0", port=port, debug=True)


if __name__ == "__main__":
    main()
