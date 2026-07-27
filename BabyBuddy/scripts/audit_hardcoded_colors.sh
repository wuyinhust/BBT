#!/bin/sh

set -eu

MODE="${1:---report}"
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

case "$MODE" in
    --report|--check) ;;
    *)
        echo "Usage: $0 [--report|--check]" >&2
        exit 2
        ;;
esac

MATCHES=$(
    rg -n \
        --glob '*.swift' \
        --glob '!FeedingSheet.swift' \
        -e 'Color\(hex:' \
        -e 'Color\.(white|black)' \
        -e '\.(foregroundStyle|foregroundColor|fill|stroke|background)\(\.(white|black)' \
        "$ROOT_DIR/BBB" "$ROOT_DIR/BaByBuddyWidget" \
        | rg -v 'color-audit: allow-fixed' \
        || true
)

if [ -z "$MATCHES" ]; then
    echo "Hard-coded color audit passed."
    exit 0
fi

COUNT=$(printf '%s\n' "$MATCHES" | wc -l | tr -d ' ')
echo "Hard-coded color audit found $COUNT unregistered occurrence(s)."
printf '%s\n' "$MATCHES"

if [ "$MODE" = "--check" ]; then
    exit 1
fi
