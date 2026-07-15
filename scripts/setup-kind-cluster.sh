#!/bin/bash
set -e

CLUSTER_NAME="piggymetrics"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Checking if kind cluster '$CLUSTER_NAME' already exists..."
if kind get clusters | grep -q "^$CLUSTER_NAME$"; then
  echo "Cluster '$CLUSTER_NAME' already exists."
else
  echo "Creating kind cluster '$CLUSTER_NAME'..."
  kind create cluster --name "$CLUSTER_NAME" --config "$SCRIPT_DIR/kind-config.yaml"
fi

# Set context to kind cluster
kubectl config use-context "kind-$CLUSTER_NAME"

# Create namespace if it doesn't exist
echo "Creating namespace 'piggymetrics' if it doesn't exist..."
kubectl create namespace piggymetrics --dry-run=client -o yaml | kubectl apply -f -

# Set default namespace to piggymetrics for current context
kubectl config set-context --current --namespace=piggymetrics

echo "Kind cluster setup complete and context set to namespace 'piggymetrics'."
