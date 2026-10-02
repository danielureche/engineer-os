#!/usr/bin/env bash

set -euo pipefail

SEARCH="${1:-}"

if [[ -z "$SEARCH" ]]; then
    echo
    echo "Usage:"
    echo "  ./scripts/find.sh <keyword>"
    echo
    echo "Example:"
    echo "  ./scripts/find.sh enrollment"
    exit 1
fi

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
    echo "✗ No namespace configured."
    exit 1
fi

echo
echo "============================================================"
echo " ENGINEER OS - RESOURCE FINDER"
echo "============================================================"
echo
echo "SEARCH    : $SEARCH"
echo "NAMESPACE : $NAMESPACE"
echo "CONTEXT   : $CONTEXT"
echo

FOUND=0
RESULTS_FILE=$(mktemp)

cleanup() {
    rm -f "$RESULTS_FILE"
}

trap cleanup EXIT

# ------------------------------------------------------------
# SERVICES
# ------------------------------------------------------------

kubectl get services -o json |
jq -r --arg search "$SEARCH" '
    .items[]
    | select(
        (
            .metadata.name
            + " "
            + (.spec.clusterIP // "")
            + " "
            + ([.spec.ports[]?.name // ""] | join(" "))
        )
        | ascii_downcase
        | contains($search | ascii_downcase)
    )
    | [
        "SERVICE",
        .metadata.name,
        (.spec.clusterIP // "-")
    ]
    | @tsv
' >> "$RESULTS_FILE"

# ------------------------------------------------------------
# DEPLOYMENTS
#
# Blue/Green identity comes from:
#
#   version.strategy=blue
#   version.strategy=green
#
# ------------------------------------------------------------

kubectl get deployments -o json |
jq -r --arg search "$SEARCH" '
    .items[]
    | select(
        (
            .metadata.name
            + " "
            + (
                .spec.template.metadata.labels
                // {}
                | to_entries
                | map(.key + "=" + (.value // ""))
                | join(" ")
            )
        )
        | ascii_downcase
        | contains($search | ascii_downcase)
    )
    | [
        "DEPLOYMENT",
        .metadata.name,
        (
            .spec.template.metadata.labels["version.strategy"]
            // "-"
        )
    ]
    | @tsv
' >> "$RESULTS_FILE"

# ------------------------------------------------------------
# DESTINATION RULES
#
# Blue/Green subsets are defined exclusively through:
#
#   version.strategy=blue
#   version.strategy=green
#
# There is NO version.active label here.
# ------------------------------------------------------------

kubectl get destinationrules -o json |
jq -r --arg search "$SEARCH" '
    .items[]
    | select(
        (
            .metadata.name
            + " "
            + (.spec.host // "")
            + " "
            + (
                [
                    .spec.subsets[]?
                    | .name // "",
                    .labels["version.strategy"] // ""
                ]
                | join(" ")
            )
        )
        | ascii_downcase
        | contains($search | ascii_downcase)
    )
    | [
        "DESTINATION_RULE",
        .metadata.name,
        (
            (.spec.host // "-")
            + " ["
            + (
                [
                    .spec.subsets[]?
                    | (
                        (.name // "-")
                        + "="
                        + (.labels["version.strategy"] // "-")
                    )
                ]
                | join(", ")
            )
            + "]"
        )
    ]
    | @tsv
' >> "$RESULTS_FILE"

# ------------------------------------------------------------
# VIRTUAL SERVICES
#
# The VirtualService determines actual traffic distribution.
#
# Blue/Green traffic is represented through:
#
#   destination.subset=blue
#   destination.subset=green
#
# ------------------------------------------------------------

kubectl get virtualservices -o json |
jq -r --arg search "$SEARCH" '
    .items[]
    | select(
        (
            .metadata.name
            + " "
            + (
                [
                    .spec.http[]?.route[]?.destination.host // "",
                    .spec.tls[]?.route[]?.destination.host // "",
                    .spec.tcp[]?.route[]?.destination.host // ""
                ]
                | join(" ")
            )
        )
        | ascii_downcase
        | contains($search | ascii_downcase)
    )
    | [
        "VIRTUAL_SERVICE",
        .metadata.name,
        (
            [
                .spec.http[]?.route[]?.destination.host // "",
                .spec.tls[]?.route[]?.destination.host // "",
                .spec.tcp[]?.route[]?.destination.host // ""
            ]
            | map(select(. != ""))
            | unique
            | join(", ")
        )
    ]
    | @tsv
' >> "$RESULTS_FILE"

# ------------------------------------------------------------
# REMOVE DUPLICATES
# ------------------------------------------------------------

if [[ ! -s "$RESULTS_FILE" ]]; then
    echo "No resources found matching: $SEARCH"
    echo
    exit 0
fi

sort -u "$RESULTS_FILE" -o "$RESULTS_FILE"

# ------------------------------------------------------------
# DISPLAY
# ------------------------------------------------------------

echo "RESULTS"
echo "------------------------------------------------------------"

INDEX=0

while IFS=$'\t' read -r TYPE NAME EXTRA; do

    INDEX=$((INDEX + 1))
    FOUND=$((FOUND + 1))

    printf "[%d] %-20s %-40s %s\n" \
        "$INDEX" \
        "$TYPE" \
        "$NAME" \
        "$EXTRA"

done < "$RESULTS_FILE"

echo
echo "------------------------------------------------------------"
echo "$FOUND resource(s) found."
echo

# ------------------------------------------------------------
# INTERACTIVE SELECTION
# ------------------------------------------------------------

if [[ "$FOUND" -eq 1 ]]; then

    SELECTED=$(head -n 1 "$RESULTS_FILE")

    IFS=$'\t' read -r TYPE NAME EXTRA <<< "$SELECTED"

    echo "Selected:"
    echo
    echo "  Type : $TYPE"
    echo "  Name : $NAME"

    if [[ -n "$EXTRA" && "$EXTRA" != "-" ]]; then
        echo "  Info : $EXTRA"
    fi

    echo

else

    while true; do

        read -r -p "Select resource [1-$FOUND] or [q]: " SELECTION

        if [[ "$SELECTION" == "q" ]]; then
            echo
            exit 0
        fi

        if [[ "$SELECTION" =~ ^[0-9]+$ ]] &&
           (( SELECTION >= 1 && SELECTION <= FOUND )); then

            SELECTED=$(sed -n "${SELECTION}p" "$RESULTS_FILE")

            IFS=$'\t' read -r TYPE NAME EXTRA <<< "$SELECTED"

            echo
            echo "============================================================"
            echo " SELECTED RESOURCE"
            echo "============================================================"
            echo
            echo "Type : $TYPE"
            echo "Name : $NAME"

            if [[ -n "$EXTRA" && "$EXTRA" != "-" ]]; then
                echo "Info : $EXTRA"
            fi

            echo
            break
        fi

        echo "Invalid selection."

    done

fi