#!/bin/sh
set -eu
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
scratch_dir=$(mktemp -d)
trap 'rm -rf "$scratch_dir"' EXIT
swiftc -parse-as-library \
  "$repo_root/Ramadan Pro/Utils/OnboardingRouter.swift" \
  "$repo_root/Ramadan Pro/Services/OnboardingJourney.swift" \
  "$repo_root/tests/onboarding_journey/main.swift" \
  -o "$scratch_dir/onboarding-journey-tests"
"$scratch_dir/onboarding-journey-tests"
