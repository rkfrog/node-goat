"""
Config for the NodeGoat insights sidecar.

DEMO ONLY: Contains intentionally hardcoded secrets so the JFrog
Secrets scanner has something to flag. Do not copy this pattern.
"""

# Hardcoded credentials (intentional for demo)
AWS_ACCESS_KEY_ID = "AKIAIOSFODNN7EXAMPLE"
AWS_SECRET_ACCESS_KEY = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"

DB_USER = "admin"
DB_PASSWORD = "Admin_123"
DB_HOST = "mongodb"

# Used to sign JWTs in the toy endpoint below
JWT_SECRET = "super-secret-jwt-signing-key-shhhh"

# Slack webhook (fake but realistic shape for secret scanner regexes)
SLACK_WEBHOOK_URL = "https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX"

# GitHub PAT (fake shape)
GITHUB_TOKEN = "ghp_aBcDeFgHiJkLmNoPqRsTuVwXyZ0123456789"

UPSTREAM_NODE_GOAT_URL = "http://node-goat:4000"
