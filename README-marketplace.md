# Deploy and Host CertMate on Railway

**Built for an LLM agent to deploy and use.** The deploy form has no fields to fill: a 64 character API token, the session key and the backup passphrase are generated, CertMate is locked behind the token from the first request, and the REST API takes it as a bearer token. CertMate is a self-hosted SSL/TLS certificate manager: Let's Encrypt and other ACME issuance, automatic renewal, certificate import, per-domain download and a REST API.

## About Hosting CertMate

This template runs one service, **certmate** (a gunicorn process serving the web app and the REST API, with certbot for issuance), with certificates, settings, backups and logs on one volume mounted at `/data`. There is no separate database service to run.

**Locked from boot.** A stock CertMate started without a valid `API_BEARER_TOKEN` comes up in setup mode and answers anonymous callers as an administrator (settings and the API key list returned 200 with no credential when reproduced on the stock image). It also writes to four separate directories under `/app` that one Railway volume cannot cover, and cannot write a root-owned volume. This template's image refuses to start without a valid token, moves every data directory under `/data`, fixes the volume permissions, drops to an unprivileged user and trusts the proxy headers Railway sends.

**What persists.** Certificates, private keys, settings, users and automatic backups live on the volume at `/data`. Backups are encrypted with `CERTMATE_BACKUP_PASSPHRASE`, a generated variable you should copy somewhere safe: CertMate never stores it, and a backup is only restorable with it.

**Using the web interface.** Open the public URL. The first screen asks for the `API_BEARER_TOKEN` value from the service variables once, to create the administrator account.

### Agent contract

- Public URL: `https://RAILWAY_PUBLIC_DOMAIN` (the generated domain of the `certmate` service)
- Private URL: `http://certmate.railway.internal:8080`
- Credentials: the variable `API_BEARER_TOKEN` on the `certmate` service (64 characters)
- Auth: send the header `Authorization: Bearer API_BEARER_TOKEN_VALUE` (the value of the `API_BEARER_TOKEN` variable) on every `/api` request; without it the API answers `401`
- Health: `GET /health` returns 200 without credentials

```bash
# Agent-contract proof for the CertMate template. Needs: SITE_URL (public https URL of the certmate service),
# API_BEARER_TOKEN (its variable); also curl, openssl (3.x), awk, sed.
H="Authorization: Bearer $API_BEARER_TOKEN"
J="Content-Type: application/json"
D=$(mktemp -d); cd "$D" || exit 1
pem() { awk 'BEGIN{ORS="\\n"}1' "$1"; }
curl -s -o /dev/null -w "health: %{http_code}\n" "$SITE_URL/health"
curl -s -o /dev/null -w "read without key: %{http_code}\n" "$SITE_URL/api/certificates"
curl -s -o /dev/null -w "write without key: %{http_code}\n" -X POST -H "$J" -d '{}' "$SITE_URL/api/certificates/import"
curl -s -o /dev/null -w "write wrong key: %{http_code}\n" -X POST -H "Authorization: Bearer wrong" -H "$J" -d '{}' "$SITE_URL/api/certificates/import"
curl -s -o /dev/null -w "settings write: %{http_code}\n" -X POST -H "$H" -H "$J" -d '{"email":"agent@example.com"}' "$SITE_URL/api/settings"
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -keyout ca.key -out ca.pem -days 30 -subj "/CN=agent-check-ca" -addext "basicConstraints=critical,CA:TRUE" -addext "keyUsage=critical,keyCertSign,cRLSign"
openssl req -x509 -CA ca.pem -CAkey ca.key -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -keyout key.pem -out leaf.pem -days 30 -subj "/CN=agent-check.example.com" -addext "basicConstraints=CA:FALSE" -addext "subjectAltName=DNS:agent-check.example.com"
printf '{"certificate":"%s","chain":"%s","private_key":"%s","auto_renew":false,"challenge_type":"http-01"}' "$(pem leaf.pem)" "$(pem ca.pem)" "$(pem key.pem)" | curl -s -o /dev/null -w "certificate import: %{http_code}\n" -X POST -H "$H" -H "$J" --data @- "$SITE_URL/api/certificates/import"
curl -s -H "$H" "$SITE_URL/api/certificates/agent-check.example.com" | sed -n 's/.*"domain": *"\([^"]*\)".*/certificate read: \1/p'
curl -s -o /dev/null -w "certificate delete: %{http_code}\n" -X DELETE -H "$H" "$SITE_URL/api/certificates/agent-check.example.com"
cd /; rm -rf "$D"
```

A fresh deploy prints (after a few `-----` lines from openssl) `health: 200`, `read without key: 401`, `write without key: 401`, `write wrong key: 401`, `settings write: 200`, `certificate import: 201`, `certificate read: agent-check.example.com` and `certificate delete: 200`.

Issuing a real certificate from Let's Encrypt additionally needs a DNS provider account added in Settings (or through `POST /api/settings`) and a domain you control; the snippet imports a throwaway certificate so it proves the write path without touching the internet.

## Why Deploy CertMate on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying CertMate on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.

- **Agent-ready** - no deployer fields, a contract block and one script that proves a read, a write, an import, a delete and the refusal without the token.
- **Locked by default** - the deploy cannot start in open setup mode.
- **Data survives redeploys** - certificates, keys and settings sit on a volume; the token and session key are stable.
- **Restorable backups** - a generated passphrase turns on encrypted disaster-recovery backups.
- **Pinned** - the image is pinned by digest.

## Common Use Cases

- **Self-hosted SSL certificate manager** - one place that issues, renews and serves Let's Encrypt certificates for many domains and providers.
- **Wildcard and internal certificates** - DNS-01 issuance across Cloudflare, Route 53 and other DNS providers without opening a port.
- **Agent-driven certificate automation** - a coding agent requests, lists, downloads and deletes certificates over the REST API.
- **Central certificate store** - import certificates issued elsewhere and fetch them from deploy scripts.

## Dependencies for CertMate Hosting

- Nothing else: state is files on the service's volume. A DNS provider account (Cloudflare, Route 53 and others) is needed only to issue real certificates, and a custom domain is optional.

### Deployment Dependencies

- [CertMate repository](https://github.com/fabriziosalmi/certmate)
- [CertMate documentation](https://github.com/fabriziosalmi/certmate/tree/main/docs)
- [Official Docker image](https://github.com/fabriziosalmi/certmate/pkgs/container/certmate)
- [Wrapper image source](https://github.com/bon5co/certmate-railway)
