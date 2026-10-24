#!/bin/sh
set -eu
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
scratch_dir=$(mktemp -d)
trap 'rm -rf "$scratch_dir"' EXIT
swiftc -parse-as-library "$repo_root/Ramadan Pro/Services/RatingPromptManager.swift" "$repo_root/tests/rating_prompt/main.swift" -o "$scratch_dir/rating-prompt-tests"
"$scratch_dir/rating-prompt-tests"
