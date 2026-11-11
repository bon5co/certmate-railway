"""Build scripts/specs/certmate.json.

    uv run --no-project python certmate/make-spec.py sha256:<digest>

CertMate = self-hosted TLS certificate manager (Flask + certbot; ACME issuance and renewal over DNS-01/HTTP-01,
deploy hooks, REST API behind a bearer token). One service, one volume at /data. Upstream's stock deploy comes
up in "setup mode" when no valid API_BEARER_TOKEN is supplied: settings, the API-key list and the admin-creation
endpoints answer an anonymous caller as an admin. It also writes to four directories under /app that one Railway
volume cannot cover, and cannot write a root-owned volume. The wrapper (bon5co/certmate-railway) refuses to start
without a valid token, moves every data directory under /data, chowns the volume and drops to the `certmate` user,
so the deploy form can be submitted empty.
"""
import json
import pathlib
import sys

here = pathlib.Path(__file__).parent

DIGEST = sys.argv[1] if len(sys.argv) > 1 else "sha256:PLACEHOLDER"
IMAGE = f"ghcr.io/bon5co/certmate-railway:2.55.2@{DIGEST}"
DESCRIPTION = "CertMate self-hosted SSL certificate manager, ACME renewal, REST API"
assert len(DESCRIPTION) <= 75, len(DESCRIPTION)

spec = [{
    "key": "certmate",
    "project_name": "CertMate",
    "display_name": "CertMate | (Just Updated) Self-Hosted SSL Certificate Manager, ACME API With Generated Token",
    "description": DESCRIPTION,
    "service_name": "certmate",
    "image": IMAGE,
    "variables": {
        "API_BEARER_TOKEN": "${{secret(64)}}",
        "SECRET_KEY": "${{secret(64)}}",
        "CERTMATE_BACKUP_PASSPHRASE": "${{secret(48)}}",
    },
    "mount_path": "/data",
    "target_port": 8080,
    "healthcheck": "/health",
    "healthcheck_timeout": 300,
    "deploy_timeout": 600,
    "start_command": None,
}]

out = here.parent / "scripts" / "specs" / "certmate.json"
out.write_text(json.dumps(spec, indent=2) + "\n")
print("wrote", out, len(DESCRIPTION), "char description")
