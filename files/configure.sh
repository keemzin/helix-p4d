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

# Ensure SSL directory permissions and p4dctl configuration if SSL is active
if [[ "${P4PORT:-}" == ssl:* ]] || [ -n "${P4SSL:-}" ]; then
    SSLDIR="${P4SSLDIR:-$P4ROOT/ssl}"
    CONF_FILE="/etc/perforce/p4dctl.conf.d/$NAME.conf"
    if [ -f "$CONF_FILE" ]; then
        if ! grep -q "P4SSLDIR" "$CONF_FILE"; then
            sed -i "/Environment/a \        P4SSLDIR  =     $SSLDIR" "$CONF_FILE"
        fi
        sed -i "s|P4PORT.*=.*|P4PORT    =     $P4PORT|" "$CONF_FILE"
    fi
    if [ -d "$SSLDIR" ]; then
        chown -R perforce:perforce "$SSLDIR" 2>/dev/null || true
        chmod 600 "$SSLDIR/privatekey.txt" 2>/dev/null || true
        chmod 644 "$SSLDIR/certificate.txt" 2>/dev/null || true
    fi
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
