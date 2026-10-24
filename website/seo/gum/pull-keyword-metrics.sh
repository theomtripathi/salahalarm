#!/usr/bin/env bash
# Pulls Google Keyword Planner volume/competition for every keyword in
# seo/data/keywords.csv through gum, one call per language, plus fresh keyword
# ideas from each language's top seeds. Writes JSON under seo/data/metrics/.
#
# Needs: gum on PATH, `gum login --service googleads`, a developer token
# (`gum auth use-ads-developer-token --stdin`) and GOOGLE_ADS_CUSTOMER_ID
# (the 10-digit Ads account id, no dashes). Read-only calls.
set -euo pipefail
cd "$(dirname "$0")/../.."

: "${GOOGLE_ADS_CUSTOMER_ID:?set GOOGLE_ADS_CUSTOMER_ID}"
today=$(date +%F)
out=seo/data/metrics
mkdir -p "$out"

# Google Ads language and geo target constant ids.
declare -A LANG_ID=([en]=1000 [ar]=1019 [tr]=1037 [id]=1025 [ur]=1041)
declare -A GEO_IDS=(
  [en]='["2840","2826","2124","2036"]'               # US GB CA AU
  [ar]='["2682","2784","2818","2414","2634","2400"]' # SA AE EG KW QA JO
  [tr]='["2792","2276","2528"]'                      # TR DE NL
  [id]='["2360","2458"]'                             # ID MY
  [ur]='["2586","2356","2826"]'                      # PK IN GB
)

for lang in en ar tr id ur; do
  keywords=$(node -e '
    const { readKeywords } = require("./seo/scripts/keywords.cjs");
    const rows = readKeywords().filter((r) => r.lang === process.argv[1]);
    process.stdout.write(JSON.stringify(rows.map((r) => r.keyword)));
  ' "$lang")
  seeds=$(node -e 'const k = JSON.parse(process.argv[1]); process.stdout.write(JSON.stringify(k.slice(0, 10)))' "$keywords")

  args=$(printf '{"customerId":"%s","keywords":%s,"language":"%s","geoTargetConstants":%s}' \
    "$GOOGLE_ADS_CUSTOMER_ID" "$keywords" "${LANG_ID[$lang]}" "${GEO_IDS[$lang]}")
  gum read googleads.keywordPlanIdeas.generateKeywordHistoricalMetrics --args "$args" --output json \
    > "$out/$today-$lang-historical.json"

  args=$(printf '{"customerId":"%s","keywords":%s,"language":"%s","geoTargetConstants":%s}' \
    "$GOOGLE_ADS_CUSTOMER_ID" "$seeds" "${LANG_ID[$lang]}" "${GEO_IDS[$lang]}")
  gum read googleads.keywordPlanIdeas.generateKeywordIdeas --args "$args" --output json \
    > "$out/$today-$lang-ideas.json"
  echo "pulled $lang"
done

node seo/scripts/import-keyword-metrics.mjs "$out"/"$today"-*.json
