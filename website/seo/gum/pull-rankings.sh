#!/usr/bin/env bash
# Pulls the last 28 days of Google Search Console data (query x page) for
# salahalarm.com through gum and prints the ranking report.
#
# Needs: gum on PATH and `gum login --service searchconsole` with a Google
# account that owns the salahalarm.com property. Read-only call.
set -euo pipefail
cd "$(dirname "$0")/../.."

site="${GSC_SITE:-sc-domain:salahalarm.com}"
end=$(date -d 'yesterday' +%F 2>/dev/null || date -v-1d +%F)
start=$(date -d '28 days ago' +%F 2>/dev/null || date -v-28d +%F)
out=seo/data/gsc
mkdir -p "$out"

body=$(printf '{"startDate":"%s","endDate":"%s","dimensions":["query","page"],"rowLimit":5000}' "$start" "$end")
args=$(printf '{"siteUrl":"%s","body":%s}' "$site" "$body")
gum read searchconsole.searchanalytics.query --args "$args" --output json > "$out/$end.json"

node seo/scripts/rank-report.mjs "$out/$end.json"
