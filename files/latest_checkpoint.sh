#!/bin/bash
set -e

# Find the most recent checkpoint file and update the 'latest' symlink.
latest=""
for file in "$P4CKP"/"$JNL_PREFIX".ckp.*; do
    [ -e "$file" ] || continue
    # Skip checksum files
    [[ "$file" == *.md5 ]] && continue
    if [ -z "$latest" ] || [ "$file" -nt "$latest" ]; then
        latest="$file"
    fi
done

if [ -n "$latest" ]; then
    ln -f -s "$latest" "$P4CKP/latest"
    echo "Updated checkpoint link: $latest -> $P4CKP/latest"
else
    echo "Error: Unable to find a checkpoint in $P4CKP for prefix '$JNL_PREFIX'" >&2
    exit 255
fi
