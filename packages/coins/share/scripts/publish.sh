#!/bin/bash

sui client switch --env mirainet

PUBLISH_RESULT=$(sui client publish --json)

PACKAGE_ID=$(echo "$PUBLISH_RESULT" | jq -r '.objectChanges[] | select(.type == "published") | .packageId')
CURRENCY_ID=$(echo "$PUBLISH_RESULT" | jq -r --arg pkg "$PACKAGE_ID" '.objectChanges[] | select(.objectType == "0x2::coin_registry::Currency<\($pkg)::share::SHARE>") | .objectId')

echo "Finalizing currency registration..."

sui client ptb \
    --move-call 0x2::coin_registry::finalize_registration "<$PACKAGE_ID::share::SHARE>" @0xc @$CURRENCY_ID \
    --json

echo ""
echo "Package ID: $PACKAGE_ID"
echo "Currency ID: $CURRENCY_ID"
echo "Currency Type: $PACKAGE_ID::share::SHARE"
echo "Success!"