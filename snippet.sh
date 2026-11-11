#!/bin/sh
# Agent-contract proof for the CertMate template. Needs: SITE_URL (public https URL of the certmate service),
# API_BEARER_TOKEN (its variable); also curl, openssl, awk.
H="Authorization: Bearer $API_BEARER_TOKEN"
J="Content-Type: application/json"
D=$(mktemp -d); cd "$D" || exit 1
pem() { awk 'BEGIN{ORS="\\n"}1' "$1"; }
curl -s -o /dev/null -w "health: %{http_code}\n" "$SITE_URL/health"
curl -s -o /dev/null -w "read without key: %{http_code}\n" "$SITE_URL/api/certificates"
curl -s -o /dev/null -w "write without key: %{http_code}\n" -X POST -H "$J" -d '{}' "$SITE_URL/api/certificates/import"
curl -s -o /dev/null -w "write wrong key: %{http_code}\n" -X POST -H "Authorization: Bearer wrong" -H "$J" -d '{}' "$SITE_URL/api/certificates/import"
curl -s -o /dev/null -w "settings write: %{http_code}\n" -X POST -H "$H" -H "$J" -d '{"email":"agent@example.com"}' "$SITE_URL/api/settings"
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -keyout ca.key -out ca.pem -days 30 -subj "/CN=agent-check-ca" -addext "basicConstraints=critical,CA:TRUE" -addext "keyUsage=critical,keyCertSign,cRLSign" 2>/dev/null
openssl req -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -keyout key.pem -out leaf.csr -subj "/CN=agent-check.example.com" 2>/dev/null
printf "subjectAltName=DNS:agent-check.example.com\nextendedKeyUsage=serverAuth\nbasicConstraints=CA:FALSE\nkeyUsage=digitalSignature\n" > ext.cnf
openssl x509 -req -in leaf.csr -CA ca.pem -CAkey ca.key -CAcreateserial -out leaf.pem -days 30 -extfile ext.cnf 2>/dev/null
printf '{"certificate":"%s","chain":"%s","private_key":"%s","auto_renew":false,"challenge_type":"http-01"}' "$(pem leaf.pem)" "$(pem ca.pem)" "$(pem key.pem)" > body.json
curl -s -o /dev/null -w "certificate import: %{http_code}\n" -X POST -H "$H" -H "$J" --data @body.json "$SITE_URL/api/certificates/import"
curl -s -H "$H" "$SITE_URL/api/certificates/agent-check.example.com" | sed -n 's/.*"domain": *"\([^"]*\)".*/certificate read: \1/p'
curl -s -o /dev/null -w "certificate delete: %{http_code}\n" -X DELETE -H "$H" "$SITE_URL/api/certificates/agent-check.example.com"
cd / && rm -rf "$D"
