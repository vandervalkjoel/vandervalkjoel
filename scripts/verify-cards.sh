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
# Usage:
#   scripts/verify-cards.sh          both sets of checks
#   scripts/verify-cards.sh local    committed streak SVGs only
#   scripts/verify-cards.sh remote   live Vercel cards only
#
# CI runs "local": the streak workflow owns the committed SVGs and must not fail
# because a separately hosted Vercel card is having a bad day.

set -euo pipefail

MODE=${1:-all}

case "$MODE" in
local | remote | all) ;;
*)
    echo "usage: $0 [local|remote|all]" >&2
    exit 2
    ;;
esac

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
#
# Newlines are flattened first, deliberately: this renderer puts each value on
# its own line, so a line-oriented grep for ">number<" never matches.
max_number() {
    tr '\n' ' ' < "$1" |
        grep -oE '>[[:space:]]*[0-9][0-9,]*[[:space:]]*<' |
        tr -cd '0-9\n' |
        sort -n |
        tail -1
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
    # "|| true" matters: without it, a no-match makes the pipeline fail under
    # pipefail, which kills the script before it can report anything.
    m=$(max_number "$f" || true)

    if [ -z "$m" ]; then
        fail "$f renders no numbers at all"
        return
    fi

    # Proves exclude_days took effect. The renderer only draws this footnote
    # when days are actually being excluded.
    if ! tr '\n' ' ' < "$f" | grep -q 'Excluding Sun, Sat'; then
        fail "$f is missing the weekend-exclusion footnote"
        return
    fi

    if [ "$m" -lt "$MIN_TOTAL" ]; then
        fail "$f largest number is $m, expected at least $MIN_TOTAL." \
            "Check the PAT and the private-contributions setting."
        return
    fi

    pass "$f renders $m"
}

# Phrases these services draw *inside* a 200-response SVG when they are broken.
# Both observed live on 2026-07-26 while setting this up, which is why checking
# the status code alone is not enough.
ERROR_PHRASES='Something went wrong|No GitHub API tokens|Please add an env variable|Can.t fetch any contribution|check your username|Maximum retries exceeded|Invalid username'

LANGS_URL="https://readme-stats-sand-zeta.vercel.app/api/top-langs?username=vandervalkjoel&exclude_repo=hyperos-ios"
# smooth, hide_points and x_axis are local patches to Joel's fork, not upstream
# features. Requesting them here means this check fails loudly if a future
# upstream sync drops the patches.
GRAPH_URL="https://readme-activity-graph-three.vercel.app/graph?username=vandervalkjoel&months=6&area=true&smooth=7&hide_points=true&x_axis=month"

# Fetch a card and assert it is a real SVG carrying no embedded error message.
# min_number > 0 additionally asserts the largest rendered value clears a floor.
check_url() {
    local label=$1 url=$2 min_number=$3
    local body status

    body=$(mktemp)
    status=$(curl -sS -o "$body" -w '%{http_code}' "$url" || echo "000")

    if [ "$status" != "200" ]; then
        fail "$label returned HTTP $status"
        rm -f "$body"
        return
    fi

    if ! head -c 400 "$body" | grep -q '<svg'; then
        fail "$label did not return SVG"
        rm -f "$body"
        return
    fi

    local found
    found=$(tr '\n' ' ' < "$body" | grep -oE "$ERROR_PHRASES" | head -1 || true)
    if [ -n "$found" ]; then
        fail "$label returned HTTP 200 but the image says: $found"
        rm -f "$body"
        return
    fi

    if [ "$min_number" -gt 0 ]; then
        local m
        m=$(max_number "$body" || true)
        if [ -z "$m" ] || [ "$m" -lt "$min_number" ]; then
            fail "$label largest number is ${m:-none}, expected at least $min_number"
            rm -f "$body"
            return
        fi
        pass "$label renders $m"
    else
        pass "$label renders clean SVG ($(wc -c < "$body" | tr -d ' ') bytes)"
    fi

    rm -f "$body"
}

if [ "$MODE" != "remote" ]; then
    echo "Checking committed streak cards"
    check_svg_file profile/streak-dark.svg
    check_svg_file profile/streak-light.svg
fi

if [ "$MODE" = "local" ]; then
    if [ "$failures" -gt 0 ]; then
        echo
        echo "$failures check(s) failed." >&2
        exit 1
    fi
    echo
    echo "All checks passed."
    exit 0
fi

echo
echo "Checking live cards"
# The languages card renders percentages, and the activity graph renders dates,
# so neither has a meaningful "big number" to assert. For those, absence of an
# embedded error message is the signal. The numeric floor still applies to the
# streak SVGs above, which is where a token failure would show up first.
check_url "languages card" "$LANGS_URL" 0
check_url "activity graph" "$GRAPH_URL" 0

if [ "$failures" -gt 0 ]; then
    echo
    echo "$failures check(s) failed." >&2
    exit 1
fi

echo
echo "All checks passed."
