#!/bin/sh
set -eu
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
scratch_dir=$(mktemp -d)
trap 'rm -rf "$scratch_dir"' EXIT
node "$repo_root/tests/localization/catalog.cjs"
xcrun xcstringstool compile "$repo_root/Ramadan Pro/Resources/Localizable.xcstrings" --output-directory "$scratch_dir"
xcrun xcstringstool compile "$repo_root/Ramadan Pro/Resources/CoreLocalizable.xcstrings" --output-directory "$scratch_dir"
swiftc -parse-as-library "$repo_root/Ramadan Pro/Utils/AppLanguage.swift" "$repo_root/tests/localization/main.swift" -o "$scratch_dir/language-tests"
"$scratch_dir/language-tests" "${1:-$scratch_dir}"
