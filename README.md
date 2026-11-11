# certmate-railway

Thin wrapper over `ghcr.io/fabriziosalmi/certmate` (CertMate, a self-hosted SSL/TLS certificate manager with ACME
issuance, renewal and a REST API) for the Railway template "CertMate". Refuses to start without a valid
`API_BEARER_TOKEN` (upstream falls back to an open setup mode that serves admin endpoints to anonymous callers), moves
all four data directories under one volume at `/data`, chowns the root-owned volume and drops to the `certmate` user
under tini, and sets `BEHIND_PROXY` and `PREFERRED_URL_SCHEME=https` for Railway's edge.
