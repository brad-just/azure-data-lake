#!/usr/bin/env bash
set -euo pipefail

CLUSTER=${AKS_CLUSTER_NAME:?AKS_CLUSTER_NAME env var is required}
RG=${AKS_RESOURCE_GROUP:?AKS_RESOURCE_GROUP env var is required}
POSTGRES=${POSTGRES_SERVER_NAME:?POSTGRES_SERVER_NAME env var is required}

echo "Starting PostgreSQL server: ${POSTGRES}"
az postgres flexible-server start --name "$POSTGRES" --resource-group "$RG"

echo "Starting AKS cluster: ${CLUSTER}"
az aks start --name "$CLUSTER" --resource-group "$RG"

echo "Waiting for AKS cluster to be ready..."
az aks wait --name "$CLUSTER" --resource-group "$RG" --updated --interval 30 --timeout 600

echo ""
echo "Done. Refresh your kubectl context:"
echo "  az aks get-credentials --name ${CLUSTER} --resource-group ${RG}"
