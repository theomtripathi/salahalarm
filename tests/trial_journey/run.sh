#!/bin/sh
set -eu
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
scratch_dir=$(mktemp -d)
trap 'rm -rf "$scratch_dir"' EXIT
swiftc -parse-as-library "$repo_root/Ramadan Pro/Services/TrialJourneyTracker.swift" "$repo_root/tests/trial_journey/main.swift" -o "$scratch_dir/trial-journey-tests"
"$scratch_dir/trial-journey-tests"
