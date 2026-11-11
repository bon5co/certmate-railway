# CertMate | (Just Updated) Self-Hosted SSL Certificate Manager, ACME API With Generated Token

Template built 2026-11-12, dokploy-queue row 94.

- **Category:** Other
- **Icon:** `https://github.com/fabriziosalmi.png`

Description (75 chars max): CertMate self-hosted SSL certificate manager, ACME renewal, REST API

Built for the LLM agent that deploys it (Handler ruling 2026-10-15): no deployer fields, an Agent contract and a snippet that proves a read, an import, a delete, and 401 on a write without a token or with a wrong one, in `README-marketplace.md`.

**Upstream defects the wrapper fixes.** (1) With `API_BEARER_TOKEN` unset or failing upstream's validation (32 to 512 characters, enough distinct characters, no placeholder substrings) CertMate starts in setup mode and serves gated endpoints (`GET /api/settings`, `GET /api/keys`) as admin to anonymous callers (reproduced on the stock image, 200 with no credential); the entrypoint refuses to start, and the variable is a generated `${{secret(64)}}`. (2) Upstream writes to `/app/data`, `/app/certificates`, `/app/backups` and `/app/logs`, which one Railway volume cannot cover; the image points `CERTMATE_{DATA,CERT,BACKUP,LOGS}_DIR` and `ACME_CHALLENGES_DIR` under `/data`. (3) The volume mounts root-owned and upstream runs as `certmate`; the entrypoint chowns `/data` and drops privileges with `setpriv` under tini. (4) `BEHIND_PROXY=true` and `PREFERRED_URL_SCHEME=https` make ProxyFix and the Secure cookie correct behind the edge. (5) `CERTMATE_BACKUP_PASSPHRASE` is a generated secret so automatic backups are restorable disaster-recovery archives rather than masked share-safe ones.

Variables: `API_BEARER_TOKEN`, `SECRET_KEY` (64 character generated secrets), `CERTMATE_BACKUP_PASSPHRASE` (48 character generated secret).

Service: `certmate` (`ghcr.io/bon5co/certmate-railway:2.55.2` pinned by digest, volume `/data`, healthcheck `/health`, target port 8080). Wrapper source: this folder and [bon5co/certmate-railway](https://github.com/bon5co/certmate-railway). Upstream version 2.55.2 (`fabriziosalmi/certmate`).

Spec: `scripts/specs/certmate.json`, written by `certmate/make-spec.py`.
