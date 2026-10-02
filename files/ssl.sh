#!/bin/bash
set -e

# Generate self-signed SSL certificates into the SSL directory.
SSLDIR="${1:-${P4SSLDIR:-/ssl}}"

mkdir -p "$SSLDIR"

# Key
openssl genrsa -out "$SSLDIR/privatekey.txt" 2048 2>/dev/null

# Certificate request + self-sign with non-interactive subject
openssl req -new -key "$SSLDIR/privatekey.txt" -out "$SSLDIR/certrequest.csr" \
    -subj "/CN=${P4NAME:-master}" 2>/dev/null
openssl x509 -req -days 365 -in "$SSLDIR/certrequest.csr" -signkey "$SSLDIR/privatekey.txt" \
    -out "$SSLDIR/certificate.txt" 2>/dev/null
rm -f "$SSLDIR/certrequest.csr"

# Secure permissions required by P4D
chmod 600 "$SSLDIR/privatekey.txt"
chmod 644 "$SSLDIR/certificate.txt"
chown -R perforce:perforce "$SSLDIR" 2>/dev/null || true

echo "SSL files written to $SSLDIR"
