#!/bin/bash
set -e

# Ensure /etc/perforce points at the server root configuration and retains p4dctl configs
if [ -d /etc/perforce ] && [ ! -L /etc/perforce ]; then
    mkdir -p "$P4ROOT/etc"
    cp -rn /etc/perforce/* "$P4ROOT/etc/" 2>/dev/null || true
    rm -rf /etc/perforce
    ln -s "$P4ROOT/etc" /etc/perforce
elif [ ! -e /etc/perforce ]; then
    mkdir -p "$P4ROOT/etc"
    ln -s "$P4ROOT/etc" /etc/perforce
fi

# Enable SSL if the server was configured with SSL directory support
if [ -n "${P4SSLDIR:-}" ]; then
    echo "Configuring SSL directory (P4SSLDIR=$P4SSLDIR)..."
    mkdir -p "$P4SSLDIR"
    chown -R perforce:perforce "$P4SSLDIR" 2>/dev/null || true
    if [ -f "$P4SSLDIR/privatekey.txt" ]; then
        chmod 600 "$P4SSLDIR/privatekey.txt"
    fi
    p4 configure set "$NAME#P4SSLDIR=$P4SSLDIR" 2>/dev/null || true
fi

# Trust server certificate if SSL port is used
if [[ "${P4PORT:-}" == ssl:* ]] || [ -n "${P4SSL:-}" ]; then
    p4 trust -y 2>/dev/null || true
fi

# Log in before triggers command if password is set
if [ -n "$P4PASSWD" ]; then
    echo "$P4PASSWD" | p4 login >/dev/null 2>&1 || true
fi

# Remove default triggers if any
echo "Triggers:" | p4 triggers -i 2>/dev/null || true
