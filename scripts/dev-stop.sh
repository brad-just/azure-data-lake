#!/usr/bin/env bash
set -euo pipefail

CLUSTER=${AKS_CLUSTER_NAME:?AKS_CLUSTER_NAME env var is required}
RG=${AKS_RESOURCE_GROUP:?AKS_RESOURCE_GROUP env var is required}
POSTGRES=${POSTGRES_SERVER_NAME:?POSTGRES_SERVER_NAME env var is required}

echo "Stopping AKS cluster: ${CLUSTER}"
az aks stop --name "$CLUSTER" --resource-group "$RG" --no-wait

echo "Stopping PostgreSQL server: ${POSTGRES}"
az postgres flexible-server stop --name "$POSTGRES" --resource-group "$RG"

echo ""
echo "Done. Both resources are stopping (AKS may take a few minutes)."
echo ""
echo "NOTE: Azure automatically restarts PostgreSQL after 7 days."
echo "      Run this script again if the environment has been idle that long."
echo ""
echo "To restart: bash scripts/dev-start.sh"
