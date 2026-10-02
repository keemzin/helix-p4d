#!/usr/bin/env bash

set -e

tag="${1:-johnsdoes/helix-p4d:2026.1}"

if [[ -z "${tag%%:*}" ]]; then
  echo "Usage: ./build.sh [name:tag]" >&2
  exit 1
fi

docker build -t "${tag}" --platform linux/amd64 .
