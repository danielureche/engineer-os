#!/usr/bin/env bash

set -euo pipefail

PROFILE="${1:-}"

if [[ -z "$PROFILE" ]]; then
    echo "Usage:"
    echo "  ./scripts/login.sh dev"
    echo "  ./scripts/login.sh qa"
    echo "  ./scripts/login.sh pdn"
    exit 1
fi

case "$PROFILE" in
    dev|qa|pdn)
        AWS_PROFILE="cnegocios-$PROFILE"
        ;;
    *)
        echo "Invalid environment: $PROFILE"
        echo "Valid values: dev, qa, pdn"
        exit 1
        ;;
esac

echo
echo "========================================"
echo " ENGINEEROS - AWS SSO"
echo "========================================"
echo
echo "Environment : $PROFILE"
echo "AWS Profile : $AWS_PROFILE"
echo

if aws sts get-caller-identity \
    --profile "$AWS_PROFILE" \
    >/dev/null 2>&1; then

    echo "✓ Existing AWS SSO session is valid."

else

    echo "⚠ AWS SSO session is not available."
    echo
    echo "→ Starting SSO login..."
    echo

    aws sso login --profile "$AWS_PROFILE"

    echo
    echo "✓ SSO login completed."
fi

echo
echo "AWS identity:"
aws sts get-caller-identity --profile "$AWS_PROFILE"

echo