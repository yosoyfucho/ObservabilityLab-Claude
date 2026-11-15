#!/usr/bin/env bash
# Genera una CA propia del lab y los certificados para mTLS entre la app y el Collector.
#
#   tls/certs/ca.crt / ca.key          CA del lab (firma todo lo demás)
#   tls/certs/collector.crt / .key     certificado de SERVIDOR del Collector
#   tls/certs/client.crt / .key        certificado de CLIENTE que presentan las apps
#
# Los archivos generados están en .gitignore: nunca se suben al repo.
# Uso: tls/gen-certs.sh          (no regenera si ya existen)
#      tls/gen-certs.sh --force  (los regenera)
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)/certs"
DAYS=365

if [[ -f "$DIR/ca.crt" && "${1:-}" != "--force" ]]; then
  echo "Certificados ya existen en $DIR (usa --force para regenerarlos)"
  exit 0
fi

rm -rf "$DIR" && mkdir -p "$DIR" && cd "$DIR"

# 1. CA del lab
openssl req -x509 -newkey rsa:4096 -sha256 -nodes -days "$DAYS" \
  -keyout ca.key -out ca.crt \
  -subj "/O=ObservabilityLab/CN=ObservabilityLab Root CA" \
  -addext "basicConstraints=critical,CA:TRUE" \
  -addext "keyUsage=critical,keyCertSign,cRLSign" 2>/dev/null

# 2. Certificado de servidor del Collector.
#    El SAN debe incluir los nombres con los que se le conecta:
#    "otel-collector" (dentro de Docker) y "localhost"/127.0.0.1 (desde tu Mac).
openssl req -newkey rsa:2048 -nodes -keyout collector.key -out collector.csr \
  -subj "/O=ObservabilityLab/CN=otel-collector" 2>/dev/null
openssl x509 -req -sha256 -days "$DAYS" -in collector.csr \
  -CA ca.crt -CAkey ca.key -CAcreateserial -out collector.crt \
  -extfile <(printf '%s\n' \
    "subjectAltName=DNS:otel-collector,DNS:localhost,IP:127.0.0.1" \
    "keyUsage=critical,digitalSignature,keyEncipherment" \
    "extendedKeyUsage=serverAuth") 2>/dev/null

# 3. Certificado de cliente para las apps (mTLS).
openssl req -newkey rsa:2048 -nodes -keyout client.key -out client.csr \
  -subj "/O=ObservabilityLab/CN=lab-app" 2>/dev/null
openssl x509 -req -sha256 -days "$DAYS" -in client.csr \
  -CA ca.crt -CAkey ca.key -CAcreateserial -out client.crt \
  -extfile <(printf '%s\n' \
    "keyUsage=critical,digitalSignature,keyEncipherment" \
    "extendedKeyUsage=clientAuth") 2>/dev/null

rm -f ./*.csr ./*.srl
# Las claves se dejan legibles (0644) porque los contenedores corren con usuarios
# no-root distintos (10001 en el Collector, appuser en la app). Solo para el lab.
chmod 0644 ./*.crt collector.key client.key
chmod 0600 ca.key

echo "Certificados generados en $DIR:"
for c in ca collector client; do
  printf '  %-10s %s\n' "$c" "$(openssl x509 -in $c.crt -noout -subject -enddate | tr '\n' ' ')"
done
