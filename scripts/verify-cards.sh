#!/usr/bin/env bash
#
# Verify the profile cards show real numbers rather than a plausible-looking zero.
#
# Why this exists: a broken card does not error. When the PAT expires or the
# "Include private contributions on my profile" setting gets turned off, the
# cards still return HTTP 200 and still render valid SVG, they just quietly
# report near-zero. "It loaded" therefore proves nothing.
#
# The signal that reliably collapses in both failure cases is the all-time
# contribution total, so that is what this asserts. On 2026-07-26 the real
# figure was 3,406, so a threshold of 3,000 catches a collapse to public-only
# data (which was 2) without failing on normal day-to-day drift.
#
# What this does NOT catch: a subtly wrong number that is still large. This is
# a smoke test for the catastrophic case, not a proof of correctness.
#
# Usage: scripts/verify-cards.sh

set -euo pipefail

MIN_TOTAL=3000

cd "$(dirname "$0")/.."

failures=0

fail() {
    echo "FAIL: $*" >&2
    failures=$((failures + 1))
}

pass() {
    echo "ok:   $*"
}

# Largest integer appearing in any text node of an SVG. The all-time
# contribution total is always the largest number these cards render.
max_number() {
    grep -oE '>[0-9][0-9,]*<' "$1" | tr -d '><,' | sort -n | tail -1
}

check_svg_file() {
    local f=$1

    if [ ! -s "$f" ]; then
        fail "$f is missing or empty"
        return
    fi

    if ! head -c 400 "$f" | grep -q '<svg'; then
        fail "$f is not an SVG"
        return
    fi

    local m
    m=$(max_number "$f")

    if [ -z "$m" ]; then
        fail "$f renders no numbers at all"
        return
    fi

    if [ "$m" -lt "$MIN_TOTAL" ]; then
        fail "$f largest number is $m, expected at least $MIN_TOTAL." \
            "Check the PAT and the private-contributions setting."
        return
    fi

    pass "$f renders $m"
}

echo "Checking committed streak cards"
check_svg_file profile/streak-dark.svg
check_svg_file profile/streak-light.svg

if [ "$failures" -gt 0 ]; then
    echo
    echo "$failures check(s) failed." >&2
    exit 1
fi

echo
echo "All checks passed."
