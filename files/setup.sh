#!/bin/bash
set -e

# Ensure /etc/perforce points to persistent configuration in $P4ROOT/etc
mkdir -p "$P4ROOT/etc"
if [ -d /etc/perforce ] && [ ! -L /etc/perforce ]; then
    cp -rn /etc/perforce/* "$P4ROOT/etc/" 2>/dev/null || true
    rm -rf /etc/perforce
    ln -s "$P4ROOT/etc" /etc/perforce
elif [ ! -e /etc/perforce ]; then
    ln -s "$P4ROOT/etc" /etc/perforce
fi

# Normalize case flag: 0 for sensitive, 1 for insensitive
CASE_NUM=0
if [[ "$P4CASE" == *1* ]]; then
    CASE_NUM=1
fi

# Register the server if not already configured in p4dctl
if ! p4dctl list 2>/dev/null | grep -q "$NAME"; then
    echo "Configuring new Perforce server '$NAME'..."
    /opt/perforce/sbin/configure-helix-p4d.sh "$NAME" -n -p "$P4PORT" -r "$P4ROOT" -u "$P4USER" -P "${P4PASSWD}" --case "$CASE_NUM" --unicode
else
    echo "Existing Perforce server '$NAME' detected."
fi

# Upgrade database schema if needed (safe no-op if already current)
if [ -f "$P4ROOT/db.counters" ] || [ -f "$P4ROOT/db.rev" ]; then
    echo "Checking / upgrading database schema..."
    runuser -u perforce -- p4d -r "$P4ROOT" -xu 2>/dev/null || true
fi

# Ensure correct file ownership
chown -R perforce:perforce "$P4HOME"

# Ensure the server is running
p4dctl start -t p4d "$NAME" 2>/dev/null || true

# If running SSL, trust server certificate for the local p4 client
if [[ "${P4PORT:-}" == ssl:* ]] || [ -n "${P4SSL:-}" ]; then
    p4 trust -y 2>/dev/null || true
fi

until p4 info -s 2>/dev/null; do sleep 1; done

# Log in before configuring
if [ -n "$P4PASSWD" ]; then
    echo "$P4PASSWD" | p4 login >/dev/null 2>&1 || true
fi

# Point the server at its depot root and journal prefix.
p4 configure set "server.depot.root=$P4DEPOTS" 2>/dev/null || true
p4 configure set "journalPrefix=$P4CKP/$JNL_PREFIX" 2>/dev/null || true
p4 configure set "$NAME#server.depot.root=$P4DEPOTS" 2>/dev/null || true
p4 configure set "$NAME#journalPrefix=$P4CKP/$JNL_PREFIX" 2>/dev/null || true
