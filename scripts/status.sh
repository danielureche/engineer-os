#!/usr/bin/env bash

set -euo pipefail

SERVICE="${1:-}"

if [[ -z "$SERVICE" ]]; then
    echo "Usage:"
    echo "  ./scripts/status.sh <service>"
    echo
    echo "Example:"
    echo "  ./scripts/status.sh ch-ms-enrollment-v2"
    exit 1
fi

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

command -v kubectl >/dev/null 2>&1 || {
    echo "✗ kubectl is required."
    exit 1
}

command -v jq >/dev/null 2>&1 || {
    echo "✗ jq is required."
    exit 1
}

NAMESPACE=$(kubectl config view \
    --minify \
    --output 'jsonpath={..namespace}')

CONTEXT=$(kubectl config current-context)

if [[ -z "$NAMESPACE" ]]; then
    echo "✗ No namespace configured in current Kubernetes context."
    exit 1
fi

# ------------------------------------------------------------
# Header
# ------------------------------------------------------------

echo
echo "============================================================"
echo " ENGINEER OS - BLUE/GREEN STATUS"
echo "============================================================"
echo
echo "SERVICE   : $SERVICE"
echo "NAMESPACE : $NAMESPACE"
echo "CONTEXT   : $CONTEXT"
echo

# ------------------------------------------------------------
# DestinationRule
#
# The DestinationRule defines the Blue/Green subsets.
#
# Example:
#
#   subsets:
#     - name: blue
#       labels:
#         version.strategy: blue
#
#     - name: green
#       labels:
#         version.strategy: green
#
# The DR does NOT define the active version.
# The active version is determined by VirtualService traffic.
# ------------------------------------------------------------

DR_JSON=$(kubectl get destinationrule -o json |
    jq -c --arg service "$SERVICE" '
        [
            .items[]
            | select(.spec.host == $service)
        ]
        | first
    ')

if [[ "$DR_JSON" == "null" || -z "$DR_JSON" ]]; then
    echo "✗ DestinationRule not found for service: $SERVICE"
    exit 1
fi

DR_NAME=$(echo "$DR_JSON" |
    jq -r '.metadata.name')

BLUE_SUBSET=$(echo "$DR_JSON" |
    jq -r '
        .spec.subsets[]?
        | select(.labels["version.strategy"] == "blue")
        | .name
    ' |
    head -n 1)

GREEN_SUBSET=$(echo "$DR_JSON" |
    jq -r '
        .spec.subsets[]?
        | select(.labels["version.strategy"] == "green")
        | .name
    ' |
    head -n 1)

echo "DESTINATION RULE"
echo "------------------------------------------------------------"

printf "%-20s : %s\n" \
    "Name" \
    "$DR_NAME"

printf "%-20s : %s\n" \
    "Blue subset" \
    "${BLUE_SUBSET:-NOT FOUND}"

printf "%-20s : %s\n" \
    "Green subset" \
    "${GREEN_SUBSET:-NOT FOUND}"

echo

if [[ -z "$BLUE_SUBSET" ]]; then
    echo "⚠ Blue subset was not found in DestinationRule."
fi

if [[ -z "$GREEN_SUBSET" ]]; then
    echo "⚠ Green subset was not found in DestinationRule."
fi

# ------------------------------------------------------------
# VirtualService
#
# The VirtualService is the source of truth for actual traffic.
#
# Example:
#
#   blue  = 100%
#   green = 0%
#
# Then:
#
#   ACTIVE = blue
#
# If:
#
#   blue  = 0%
#   green = 100%
#
# Then:
#
#   ACTIVE = green
# ------------------------------------------------------------

echo "VIRTUAL SERVICE"
echo "------------------------------------------------------------"

VS_JSON=$(kubectl get virtualservice -o json |
    jq -c --arg service "$SERVICE" '
        [
            .items[]
            | select(
                any(
                    .spec.http[]?.route[]?.destination?;
                    .host == $service
                )
            )
        ]
        | first
    ')

BLUE_WEIGHT=0
GREEN_WEIGHT=0
VS_NAME=""

if [[ "$VS_JSON" != "null" && -n "$VS_JSON" ]]; then

    VS_NAME=$(echo "$VS_JSON" |
        jq -r '.metadata.name')

    BLUE_WEIGHT=$(echo "$VS_JSON" |
        jq -r '
            [
                .spec.http[]?.route[]?
                | select(.destination.subset == "blue")
                | (.weight // 0)
            ]
            | add // 0
        ')

    GREEN_WEIGHT=$(echo "$VS_JSON" |
        jq -r '
            [
                .spec.http[]?.route[]?
                | select(.destination.subset == "green")
                | (.weight // 0)
            ]
            | add // 0
        ')

    printf "%-20s : %s\n" \
        "Name" \
        "$VS_NAME"

    printf "%-20s : %s%%\n" \
        "Blue traffic" \
        "$BLUE_WEIGHT"

    printf "%-20s : %s%%\n" \
        "Green traffic" \
        "$GREEN_WEIGHT"

else

    echo "✗ VirtualService not found for service."

fi

echo

# ------------------------------------------------------------
# Determine ACTIVE VERSION
#
# Active version comes from VirtualService traffic.
#
# 100% Blue  -> BLUE ACTIVE
# 100% Green -> GREEN ACTIVE
#
# Anything else means traffic is split or inconsistent.
# ------------------------------------------------------------

ACTIVE_VERSION=""

if [[ "$BLUE_WEIGHT" == "100" && "$GREEN_WEIGHT" == "0" ]]; then

    ACTIVE_VERSION="blue"

elif [[ "$GREEN_WEIGHT" == "100" && "$BLUE_WEIGHT" == "0" ]]; then

    ACTIVE_VERSION="green"

fi

# ------------------------------------------------------------
# Service
#
# We use the Service selector as the first correlation point.
# ------------------------------------------------------------

SERVICE_JSON=$(kubectl get service "$SERVICE" \
    -o json 2>/dev/null || true)

if [[ -z "$SERVICE_JSON" ]]; then
    echo "✗ Kubernetes Service not found: $SERVICE"
    exit 1
fi

SELECTOR=$(echo "$SERVICE_JSON" |
    jq -c '.spec.selector // {}')

# ------------------------------------------------------------
# Deployments
#
# Deployments are correlated through:
#
#   1. Service selector
#   2. version.strategy label
#
# Expected:
#
#   deployment-blue
#       version.strategy=blue
#
#   deployment-green
#       version.strategy=green
# ------------------------------------------------------------

echo "DEPLOYMENTS"
echo "------------------------------------------------------------"

DEPLOYMENTS_FOUND=0

BLUE_DEPLOYMENT=""
GREEN_DEPLOYMENT=""

BLUE_READY=0
BLUE_DESIRED=0

GREEN_READY=0
GREEN_DESIRED=0

while IFS= read -r DEPLOYMENT_JSON; do

    [[ -z "$DEPLOYMENT_JSON" ]] && continue

    DEPLOYMENT_NAME=$(echo "$DEPLOYMENT_JSON" |
        jq -r '.metadata.name')

    LABELS=$(echo "$DEPLOYMENT_JSON" |
        jq -c '.spec.template.metadata.labels // {}')

    # --------------------------------------------------------
    # Check Service selector
    # --------------------------------------------------------

    MATCHES=$(jq -n \
        --argjson selector "$SELECTOR" \
        --argjson labels "$LABELS" '
        all(
            ($selector | to_entries[]);
            $labels[.key] == .value
        )
    ')

    [[ "$MATCHES" != "true" ]] && continue

    # --------------------------------------------------------
    # Get Blue/Green version
    # --------------------------------------------------------

    VERSION=$(echo "$LABELS" |
        jq -r '."version.strategy" // empty')

    [[ "$VERSION" != "blue" && "$VERSION" != "green" ]] && continue

    READY=$(echo "$DEPLOYMENT_JSON" |
        jq -r '.status.readyReplicas // 0')

    DESIRED=$(echo "$DEPLOYMENT_JSON" |
        jq -r '.spec.replicas // 0')

    printf "%-16s %-38s %-8s %s/%s\n" \
        "$SERVICE" \
        "$DEPLOYMENT_NAME" \
        "${VERSION^^}" \
        "$READY" \
        "$DESIRED"

    DEPLOYMENTS_FOUND=$((DEPLOYMENTS_FOUND + 1))

    if [[ "$VERSION" == "blue" ]]; then

        BLUE_DEPLOYMENT="$DEPLOYMENT_NAME"
        BLUE_READY="$READY"
        BLUE_DESIRED="$DESIRED"

    elif [[ "$VERSION" == "green" ]]; then

        GREEN_DEPLOYMENT="$DEPLOYMENT_NAME"
        GREEN_READY="$READY"
        GREEN_DESIRED="$DESIRED"

    fi

done < <(
    kubectl get deployments -o json |
    jq -c '.items[]'
)

if [[ "$DEPLOYMENTS_FOUND" -eq 0 ]]; then
    echo "No Blue/Green deployments found."
fi

echo

# ------------------------------------------------------------
# Determine ACTIVE DEPLOYMENT
# ------------------------------------------------------------

ACTIVE_DEPLOYMENT=""

if [[ "$ACTIVE_VERSION" == "blue" ]]; then

    ACTIVE_DEPLOYMENT="$BLUE_DEPLOYMENT"

elif [[ "$ACTIVE_VERSION" == "green" ]]; then

    ACTIVE_DEPLOYMENT="$GREEN_DEPLOYMENT"

fi

# ------------------------------------------------------------
# Determine STRATEGY VERSION
#
# Since the VirtualService tells us what is active, the other
# Blue/Green version is the candidate/strategy version.
#
# Example:
#
#   ACTIVE = blue
#   STRATEGY = green
#
# or:
#
#   ACTIVE = green
#   STRATEGY = blue
# ------------------------------------------------------------

STRATEGY_VERSION=""

if [[ "$ACTIVE_VERSION" == "blue" ]]; then

    STRATEGY_VERSION="green"

elif [[ "$ACTIVE_VERSION" == "green" ]]; then

    STRATEGY_VERSION="blue"

fi

STRATEGY_DEPLOYMENT=""

if [[ "$STRATEGY_VERSION" == "blue" ]]; then

    STRATEGY_DEPLOYMENT="$BLUE_DEPLOYMENT"

elif [[ "$STRATEGY_VERSION" == "green" ]]; then

    STRATEGY_DEPLOYMENT="$GREEN_DEPLOYMENT"

fi

# ------------------------------------------------------------
# HPA
#
# HPA should exist only for the ACTIVE deployment.
# ------------------------------------------------------------

echo "HPA"
echo "------------------------------------------------------------"

HPA_FOUND=0

while IFS= read -r HPA_JSON; do

    [[ -z "$HPA_JSON" ]] && continue

    HPA_NAME=$(echo "$HPA_JSON" |
        jq -r '.metadata.name')

    TARGET=$(echo "$HPA_JSON" |
        jq -r '.spec.scaleTargetRef.name')

    if [[ "$TARGET" == "$ACTIVE_DEPLOYMENT" ]]; then

        MIN=$(echo "$HPA_JSON" |
            jq -r '.spec.minReplicas // "-"')

        MAX=$(echo "$HPA_JSON" |
            jq -r '.spec.maxReplicas // "-"')

        CURRENT=$(echo "$HPA_JSON" |
            jq -r '.status.currentReplicas // "-"')

        printf "%-20s : %s\n" \
            "Name" \
            "$HPA_NAME"

        printf "%-20s : %s\n" \
            "Target" \
            "$TARGET"

        printf "%-20s : %s\n" \
            "Version" \
            "${ACTIVE_VERSION^^}"

        printf "%-20s : min=%s max=%s current=%s\n" \
            "Replicas" \
            "$MIN" \
            "$MAX" \
            "$CURRENT"

        HPA_FOUND=1

    fi

done < <(
    kubectl get hpa -o json |
    jq -c '.items[]'
)

if [[ "$HPA_FOUND" -eq 0 ]]; then
    echo "No HPA found for active deployment."
fi

echo

# ------------------------------------------------------------
# RESULT
# ------------------------------------------------------------

echo "RESULT"
echo "------------------------------------------------------------"

printf "%-20s : %s\n" \
    "ACTIVE VERSION" \
    "${ACTIVE_VERSION^^:-NOT DETERMINED}"

printf "%-20s : %s\n" \
    "ACTIVE DEPLOYMENT" \
    "${ACTIVE_DEPLOYMENT:-NOT FOUND}"

printf "%-20s : %s\n" \
    "STRATEGY VERSION" \
    "${STRATEGY_VERSION^^:-NOT DETERMINED}"

printf "%-20s : %s\n" \
    "STRATEGY DEPLOYMENT" \
    "${STRATEGY_DEPLOYMENT:-NOT FOUND}"

echo

# ------------------------------------------------------------
# Traffic consistency
# ------------------------------------------------------------

TRAFFIC_OK="true"

if [[ "$BLUE_WEIGHT" == "100" && "$GREEN_WEIGHT" == "0" ]]; then

    if [[ "$ACTIVE_VERSION" != "blue" ]]; then
        TRAFFIC_OK="false"
    fi

elif [[ "$GREEN_WEIGHT" == "100" && "$BLUE_WEIGHT" == "0" ]]; then

    if [[ "$ACTIVE_VERSION" != "green" ]]; then
        TRAFFIC_OK="false"
    fi

else

    TRAFFIC_OK="false"

fi

# ------------------------------------------------------------
# Deployment consistency
# ------------------------------------------------------------

DEPLOYMENT_OK="true"

if [[ -z "$ACTIVE_DEPLOYMENT" ]]; then
    DEPLOYMENT_OK="false"
fi

if [[ -z "$STRATEGY_DEPLOYMENT" ]]; then
    DEPLOYMENT_OK="false"
fi

# ------------------------------------------------------------
# Final state
# ------------------------------------------------------------

if [[ "$TRAFFIC_OK" == "false" ]]; then

    echo "STATE                : INCONSISTENT STATE"
    echo "REASON               : VirtualService traffic is not 100% on one version."

elif [[ "$DEPLOYMENT_OK" == "false" ]]; then

    echo "STATE                : INCOMPLETE STATE"
    echo "REASON               : Blue/Green deployments could not be correlated."

elif [[ "$ACTIVE_VERSION" == "$STRATEGY_VERSION" ]]; then

    echo "STATE                : UNIFIED"

else

    echo "STATE                : ${STRATEGY_VERSION^^} BEING PREPARED"
    echo "NEXT ACTION          : TEST ${STRATEGY_VERSION^^} → SWITCH ACTIVE TO ${STRATEGY_VERSION^^}"

fi

echo
echo "============================================================"
echo