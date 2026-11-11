# CertMate for Railway.
#
# A stock deploy of upstream CertMate has three defects on Railway. Without a valid API_BEARER_TOKEN it comes up in
# "setup mode", which serves every gated endpoint to an anonymous caller as an admin (settings, API keys, private
# keys, new admin users) until someone completes the first-run screen. It writes settings, issued certificates (with
# their private keys), backups and logs to four separate directories under /app, and Railway mounts one volume per
# path, root-owned, while the image runs as the unprivileged `certmate` user, so none of them persists or is writable.
# It also ignores the X-Forwarded-* headers unless BEHIND_PROXY is set, so every link and cookie is built for plain http.
# This wrapper refuses to start without a valid bearer token, moves all four directories under one volume at /data,
# chowns it and drops to `certmate`, and turns on the proxy settings. The application itself is untouched.
FROM ghcr.io/fabriziosalmi/certmate:2.55.2@sha256:414d0e60e50d8148d244b54f244029a13824d36025e7502a6d1d576bbb1abd0c

USER root
COPY railway-entrypoint.sh /usr/local/bin/railway-entrypoint.sh
RUN chmod +x /usr/local/bin/railway-entrypoint.sh

ENV CERTMATE_DATA_DIR=/data/data \
    CERTMATE_CERT_DIR=/data/certificates \
    CERTMATE_BACKUP_DIR=/data/backups \
    CERTMATE_LOGS_DIR=/data/logs \
    ACME_CHALLENGES_DIR=/data/data/acme-challenges \
    BEHIND_PROXY=true \
    PREFERRED_URL_SCHEME=https

WORKDIR /app
VOLUME /data
EXPOSE 8000
ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
CMD ["sh", "-c", "gunicorn --bind 0.0.0.0:${PORT} --workers 1 --threads 8 --timeout ${GUNICORN_TIMEOUT} --access-logfile - --error-logfile - --log-level info app:app"]
