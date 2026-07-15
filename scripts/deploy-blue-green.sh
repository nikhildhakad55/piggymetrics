#!/bin/bash
# deploy-blue-green.sh
# Usage: ./deploy-blue-green.sh <service-name> <image-tag> [docker-hub-user]

set -e

SERVICE_NAME=$1
IMAGE_TAG=$2
DOCKER_USER=${3:-sqshq} # Default to 'sqshq' if not specified

if [ -z "$SERVICE_NAME" ] || [ -z "$IMAGE_TAG" ]; then
  echo "Usage: $0 <service-name> <image-tag> [docker-hub-user]"
  exit 1
fi

NAMESPACE="piggymetrics"
IMAGE_NAME="${DOCKER_USER}/piggymetrics-${SERVICE_NAME}"

echo "=========================================="
echo "Starting Blue-Green deployment for $SERVICE_NAME"
echo "Target Image: $IMAGE_NAME:$IMAGE_TAG"
echo "=========================================="

# 1. Get current active color from the Service selector
ACTIVE_COLOR=$(kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.selector.color}' 2>/dev/null || echo "")

if [ -z "$ACTIVE_COLOR" ]; then
  echo "No active color found. Assuming this is the initial deployment. Defaulting to 'blue'."
  ACTIVE_COLOR="green" # so the target new color will be blue
fi

if [ "$ACTIVE_COLOR" == "blue" ]; then
  NEW_COLOR="green"
  OLD_COLOR="blue"
else
  NEW_COLOR="blue"
  OLD_COLOR="green"
fi

echo "Current active version: $OLD_COLOR"
echo "Deploying new version to: $NEW_COLOR"

TARGET_DEPLOYMENT="${SERVICE_NAME}-${NEW_COLOR}"
OLD_DEPLOYMENT="${SERVICE_NAME}-${OLD_COLOR}"

# 2. Check if target deployment exists
if ! kubectl get deployment "$TARGET_DEPLOYMENT" -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "Error: Deployment $TARGET_DEPLOYMENT does not exist in namespace $NAMESPACE."
  exit 1
fi

# 3. Update the target deployment's image and scale it up to 1 replica (in case it was 0)
echo "Updating deployment $TARGET_DEPLOYMENT image to $IMAGE_NAME:$IMAGE_TAG..."
kubectl set image deployment/"$TARGET_DEPLOYMENT" "$SERVICE_NAME"="$IMAGE_NAME:$IMAGE_TAG" -n "$NAMESPACE"

echo "Scaling up deployment $TARGET_DEPLOYMENT to 1 replica..."
kubectl scale deployment/"$TARGET_DEPLOYMENT" --replicas=1 -n "$NAMESPACE"

# 4. Wait for the new deployment to become healthy
echo "Waiting for rollout of $TARGET_DEPLOYMENT to complete..."
if kubectl rollout status deployment/"$TARGET_DEPLOYMENT" -n "$NAMESPACE" --timeout=180s; then
  echo "Rollout of $TARGET_DEPLOYMENT successful!"
  
  # 5. Switch traffic: update service selector to point to the new color
  echo "Switching traffic from $OLD_COLOR to $NEW_COLOR..."
  kubectl patch svc "$SERVICE_NAME" -n "$NAMESPACE" -p "{\"spec\":{\"selector\":{\"color\":\"$NEW_COLOR\"}}}"
  
  # 6. Scale down the old deployment to 0 replicas
  echo "Scaling down old deployment $OLD_DEPLOYMENT to 0 replicas..."
  kubectl scale deployment/"$OLD_DEPLOYMENT" --replicas=0 -n "$NAMESPACE"
  
  echo "Blue-Green deployment for $SERVICE_NAME completed successfully!"
  echo "=========================================="
else
  echo "=========================================="
  echo "WARNING: Rollout of $TARGET_DEPLOYMENT failed or timed out!"
  echo "Rolling back deployment. Keeping traffic on active version: $OLD_COLOR."
  echo "Scaling down unhealthy deployment $TARGET_DEPLOYMENT to 0 replicas..."
  kubectl scale deployment/"$TARGET_DEPLOYMENT" --replicas=0 -n "$NAMESPACE"
  echo "Rollback completed. Service traffic was not affected."
  echo "=========================================="
  exit 1
fi
