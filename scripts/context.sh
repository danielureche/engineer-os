#!/usr/bin/env bash

set -euo pipefail

ENVIRONMENT="${1:-}"

if [[ -z "$ENVIRONMENT" ]]; then
    echo "Usage:"
    echo "  ./scripts/context.sh dev"
    echo "  ./scripts/context.sh qa"
    echo "  ./scripts/context.sh pdn"
    exit 1
fi

case "$ENVIRONMENT" in
    dev|qa|pdn)
        AWS_PROFILE="cnegocios-$ENVIRONMENT"
        CLUSTER="eks-canalnegocios-$ENVIRONMENT"
        NAMESPACE="canalnegocios-$ENVIRONMENT"
        ;;
    *)
        echo "Invalid environment: $ENVIRONMENT"
        echo "Valid values: dev, qa, pdn"
        exit 1
        ;;
esac

# Obtener la región configurada en el perfil AWS.
AWS_REGION=$(aws configure get region --profile "$AWS_PROFILE")

if [[ -z "$AWS_REGION" ]]; then
    echo "✗ No AWS region configured for profile: $AWS_PROFILE"
    echo
    echo "Configure it with:"
    echo "  aws configure set region <region> --profile $AWS_PROFILE"
    exit 1
fi

echo
echo "========================================"
echo " ENGINEER OS - CONTEXT"
echo "========================================"
echo
echo "Environment : $ENVIRONMENT"
echo "AWS Profile : $AWS_PROFILE"
echo "EKS Cluster : $CLUSTER"
echo "Namespace   : $NAMESPACE"
echo "AWS Region  : $AWS_REGION"
echo

# ------------------------------------------------------------
# AWS SESSION
# ------------------------------------------------------------

echo "→ Checking AWS SSO..."

if ! aws sts get-caller-identity \
    --profile "$AWS_PROFILE" \
    >/dev/null 2>&1; then

    echo "⚠ AWS session expired or unavailable."
    echo
    echo "→ Starting AWS SSO login..."
    echo

    aws sso login --profile "$AWS_PROFILE"
fi

echo "✓ AWS session valid."

# ------------------------------------------------------------
# EKS KUBECONFIG
# ------------------------------------------------------------

echo
echo "→ Updating EKS kubeconfig..."

aws eks update-kubeconfig \
    --name "$CLUSTER" \
    --region "$AWS_REGION" \
    --profile "$AWS_PROFILE"

echo "✓ kubeconfig updated."

# ------------------------------------------------------------
# KUBERNETES CONTEXT
# ------------------------------------------------------------

CURRENT_CONTEXT=$(kubectl config current-context)

echo
echo "→ Kubernetes context:"
echo "  $CURRENT_CONTEXT"

echo
echo "→ Setting namespace..."

kubectl config set-context "$CURRENT_CONTEXT" \
    --namespace="$NAMESPACE" \
    >/dev/null

echo "✓ Namespace configured."

# ------------------------------------------------------------
# KUBERNETES CONNECTION
# ------------------------------------------------------------

echo
echo "→ Testing Kubernetes connection..."

if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    echo "✓ Kubernetes connection OK."
else
    echo "✗ Could not access namespace: $NAMESPACE"
    exit 1
fi

CURRENT_NAMESPACE=$(kubectl config view \
    --minify \
    --output 'jsonpath={..namespace}')

# ------------------------------------------------------------
# CURRENT CONTEXT
# ------------------------------------------------------------

echo
echo "========================================"
echo " CURRENT CONTEXT"
echo "========================================"
echo
echo "AWS Profile : $AWS_PROFILE"
echo "AWS Region  : $AWS_REGION"
echo "EKS Cluster : $CLUSTER"
echo "K8s Context : $CURRENT_CONTEXT"
echo "Namespace   : $CURRENT_NAMESPACE"
echo

# ------------------------------------------------------------
# AWS IDENTITY
# ------------------------------------------------------------

echo "========================================"
echo " AWS IDENTITY"
echo "========================================"

aws sts get-caller-identity \
    --profile "$AWS_PROFILE"

# ------------------------------------------------------------
# READY
# ------------------------------------------------------------

echo
echo "========================================"
echo " STATUS: READY"
echo "========================================"
echo