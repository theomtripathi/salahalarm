#!/usr/bin/env bash
# Tells Search Console to re-read the sitemap after a new article is live.
# This is a write call, so gum needs --allow-write. Run it only after deploy.
set -euo pipefail
site="${GSC_SITE:-sc-domain:salahalarm.com}"
args=$(printf '{"siteUrl":"%s","feedpath":"https://salahalarm.com/sitemap.xml"}' "$site")
gum write searchconsole.sitemaps.submit --allow-write --args "$args"
