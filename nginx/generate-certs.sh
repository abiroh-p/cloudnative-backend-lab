#!/bin/sh
# WHY self-signed and generated locally, not committed to git:
# A self-signed cert's PRIVATE KEY is exactly as sensitive as a password —
# it should never be sitting in version control. Anyone running this
# project generates their own; browsers/curl will complain it's untrusted
# (expected — there's no real Certificate Authority behind a self-signed
# cert), which is fine for local learning. Stage 4+ / any real deployment
# would use a real CA (e.g. Let's Encrypt via cert-manager in AKS) instead.

set -e
cd "$(dirname "$0")"
mkdir -p certs

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout certs/localhost.key \
  -out certs/localhost.crt \
  -subj "/CN=localhost" \
  -addext "subjectAltName=DNS:localhost"

echo "Self-signed certificate generated at nginx/certs/"
echo "(gitignored — regenerate any time with this script)"
