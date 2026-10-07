#!/bin/bash
set -e

# Generate self-signed SSL certificates into the SSL directory.
SSLDIR="${1:-${P4SSLDIR:-${P4ROOT:-/opt/perforce/p4/home/root}/ssl}}"

mkdir -p "$SSLDIR"

# Generate 2048-bit RSA private key
openssl genrsa -out "$SSLDIR/privatekey.txt" 2048 2>/dev/null

# Generate self-signed certificate directly in one step (fast and non-interactive)
openssl req -new -x509 -days 365 -nodes \
    -key "$SSLDIR/privatekey.txt" \
    -out "$SSLDIR/certificate.txt" \
    -subj "/CN=${P4NAME:-master}" 2>/dev/null

# Secure permissions required by P4D
chmod 600 "$SSLDIR/privatekey.txt"
chmod 644 "$SSLDIR/certificate.txt"
chown -R perforce:perforce "$SSLDIR" 2>/dev/null || true

echo "SSL files written to $SSLDIR"

