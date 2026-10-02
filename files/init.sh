#!/bin/bash
set -e

# Allow running helper scripts or arbitrary commands via the entrypoint
if [ $# -gt 0 ]; then
    case "$1" in
        ssl.sh|/usr/local/bin/ssl.sh)
            shift
            exec /usr/local/bin/ssl.sh "$@"
            ;;
        restore.sh|/usr/local/bin/restore.sh)
            shift
            exec /usr/local/bin/restore.sh "$@"
            ;;
        latest_checkpoint.sh|/usr/local/bin/latest_checkpoint.sh)
            shift
            exec /usr/local/bin/latest_checkpoint.sh "$@"
            ;;
        bash|sh|p4|p4d|p4dctl)
            exec "$@"
            ;;
    esac
fi

# Ensure directories exist and are owned by perforce
mkdir -p "$P4ROOT" "$P4DEPOTS" "$P4CKP" "$P4LOG" "$P4JOURNAL" "$P4ROOT/etc"

# Ensure /etc/perforce points to persistent configuration in $P4ROOT/etc
if [ -d /etc/perforce ] && [ ! -L /etc/perforce ]; then
    cp -rn /etc/perforce/* "$P4ROOT/etc/" 2>/dev/null || true
    rm -rf /etc/perforce
    ln -s "$P4ROOT/etc" /etc/perforce
elif [ ! -e /etc/perforce ]; then
    ln -s "$P4ROOT/etc" /etc/perforce
fi

chown -R perforce:perforce "$P4HOME"

# Restore checkpoint if symlink latest exists, otherwise create or start server.
if [ -L "$P4CKP/latest" ]; then
    echo "Restoring checkpoint..."
    /usr/local/bin/restore.sh
    rm -f "$P4CKP/latest"
else
    /usr/local/bin/setup.sh
fi

/usr/local/bin/configure.sh

# Trust server certificate if SSL is configured
if [[ "${P4PORT:-}" == ssl:* ]] || [ -n "${P4SSL:-}" ]; then
    p4 trust -y 2>/dev/null || true
fi

# Wait until the server answers.
until p4 info -s 2>/dev/null; do sleep 1; done

echo "Perforce Server [RUNNING]"

# Graceful shutdown handler
cleanup() {
    echo "Received termination signal. Stopping Perforce Server cleanly..."
    p4dctl stop "$NAME" 2>/dev/null || true
    exit 0
}
trap cleanup SIGTERM SIGINT

# Ensure log file exists for tail
touch "$P4LOG/log"
chown perforce:perforce "$P4LOG/log"

# Tail log file in foreground and wait for signals
tail -F "$P4LOG/log" &
wait $!
