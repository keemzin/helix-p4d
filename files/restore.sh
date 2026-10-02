#!/bin/bash
set -e

# Resolve the 'latest' checkpoint link, stopping the server first if needed.
if [ -L "$P4CKP/latest" ]; then
    echo "Stopping Perforce before restore..."
    p4dctl stop "$NAME" 2>/dev/null || true
    until ! p4 info -s 2>/dev/null; do sleep 1; done
fi

# Locate a checkpoint if the link is missing.
if [ ! -L "$P4CKP/latest" ]; then
    echo "Link not found - looking for checkpoint"
    /usr/local/bin/latest_checkpoint.sh
fi

if [ ! -L "$P4CKP/latest" ]; then
    echo "Error: Checkpoint for link $P4CKP/latest not found." >&2
    exit 255
fi

# Clear existing database tables in server root before journal replay.
# Note: Versioned depot files in P4DEPOTS are preserved!
echo "Clearing database tables in $P4ROOT..."
rm -f "$P4ROOT"/db.*

echo "$P4NAME" > "$P4ROOT/server.id"

# Normalize case flag for p4d binary: -C0 or -C1
CASE_FLAG="-C0"
if [[ "$P4CASE" == *1* ]]; then
    CASE_FLAG="-C1"
fi

CHECKPOINT="$P4CKP/latest"
Z_FLAG=""
if gzip -t "$CHECKPOINT" 2>/dev/null; then
    Z_FLAG="-z"
fi

echo "Restoring checkpoint from $CHECKPOINT..."
runuser -u perforce -- p4d "$CASE_FLAG" -r "$P4ROOT" -jr $Z_FLAG "$CHECKPOINT"
runuser -u perforce -- p4d "$CASE_FLAG" -r "$P4ROOT" -xu
runuser -u perforce -- p4d "$CASE_FLAG" -r "$P4ROOT" -cset "security=2"
runuser -u perforce -- p4d "$CASE_FLAG" -r "$P4ROOT" -cset "${P4NAME}#server.depot.root=${P4DEPOTS}"
runuser -u perforce -- p4d "$CASE_FLAG" -r "$P4ROOT" -cset "${P4NAME}#journalPrefix=${P4CKP}/${JNL_PREFIX}"

chown -R perforce:perforce "$P4HOME"

# Start server under p4dctl service management
echo "Starting restored server..."
p4dctl start -t p4d "$NAME" 2>/dev/null || true
