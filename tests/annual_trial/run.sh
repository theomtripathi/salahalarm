#!/bin/sh
set -eu
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
scratch_dir=$(mktemp -d)
trap 'rm -rf "$scratch_dir"' EXIT
swiftc "$repo_root/Ramadan Pro/Models/Subscription.swift" "$repo_root/tests/annual_trial/main.swift" -o "$scratch_dir/annual-trial-tests"
"$scratch_dir/annual-trial-tests"
