#!/bin/sh
# CertMate for Railway: refuse to start in setup mode (no valid bearer token = an anonymous admin), make the
# root-owned volume writable, then run upstream as the `certmate` user under tini.
set -eu

# Upstream falls back to an open setup mode when API_BEARER_TOKEN is unset or fails its own validation
# (32 to 512 characters, at least 8 distinct, not a placeholder). Fail loudly instead of serving an admin to anyone.
if [ -z "${API_BEARER_TOKEN:-}" ] || [ "${#API_BEARER_TOKEN}" -lt 32 ] || [ "${#API_BEARER_TOKEN}" -gt 512 ]; then
  echo "railway-entrypoint: API_BEARER_TOKEN must be 32 to 512 characters; refusing to start CertMate in setup mode" >&2
  exit 1
fi

# Sessions survive a redeploy only if the signing key does.
if [ -z "${SECRET_KEY:-}" ]; then
  echo "railway-entrypoint: SECRET_KEY is empty; refusing to start with a per-boot session key" >&2
  exit 1
fi

# Railway's HTTP healthcheck dials the injected PORT; the listener follows it.
export PORT="${PORT:-8000}"

mkdir -p "$CERTMATE_DATA_DIR" "$CERTMATE_CERT_DIR" "$CERTMATE_BACKUP_DIR" "$CERTMATE_LOGS_DIR" "$ACME_CHALLENGES_DIR"
chown -R certmate:certmate /data
chmod 700 "$CERTMATE_CERT_DIR" "$CERTMATE_DATA_DIR"
echo "railway-entrypoint: /data owner=$(stat -c %u:%g /data) port=$PORT behind_proxy=$BEHIND_PROXY"

export HOME=/home/certmate
exec setpriv --reuid=certmate --regid=certmate --init-groups tini -- "$@"
