#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
source_file="$repo_root/Ramadan Pro/ViewModels/SubscriptionViewModel.swift"
test_file="$repo_root/tests/purchase_error_classifier/main.swift"
scratch_dir=$(mktemp -d)
trap 'rm -rf "$scratch_dir"' EXIT

awk '
    /PURCHASE_ERROR_CLASSIFIER_BEGIN/ { copying = 1; next }
    /PURCHASE_ERROR_CLASSIFIER_END/ { copying = 0; next }
    copying { print }
' "$source_file" > "$scratch_dir/PurchaseErrorClassifier.swift"

if [ ! -s "$scratch_dir/PurchaseErrorClassifier.swift" ]; then
    echo "Could not extract production purchase error classifier" >&2
    exit 1
fi

swiftc -D PURCHASE_CLASSIFIER_STANDALONE "$scratch_dir/PurchaseErrorClassifier.swift" "$test_file" -o "$scratch_dir/classifier-tests"
"$scratch_dir/classifier-tests"
