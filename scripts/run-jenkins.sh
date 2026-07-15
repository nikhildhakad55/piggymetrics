#!/bin/bash
# run-jenkins.sh
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Building custom Jenkins image (with Docker CLI and kubectl)..."
docker build -t piggymetrics-jenkins -f "$SCRIPT_DIR/jenkins.Dockerfile" "$SCRIPT_DIR"

echo "Configuring Kubeconfig for container access..."
mkdir -p "$SCRIPT_DIR/.kube"
if [ -f "$HOME/.kube/config" ]; then
  cp "$HOME/.kube/config" "$SCRIPT_DIR/.kube/config"
  # Replace 127.0.0.1 or localhost with host.docker.internal so the container can access the host's Kind cluster API
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' 's/127.0.0.1/host.docker.internal/g' "$SCRIPT_DIR/.kube/config"
    sed -i '' 's/localhost/host.docker.internal/g' "$SCRIPT_DIR/.kube/config"
  else
    sed -i 's/127.0.0.1/host.docker.internal/g' "$SCRIPT_DIR/.kube/config"
    sed -i 's/localhost/host.docker.internal/g' "$SCRIPT_DIR/.kube/config"
  fi
  # Strip certificate authority data and add insecure-skip-tls-verify: true to prevent TLS verification failures
  python3 -c "
import re
with open('$SCRIPT_DIR/.kube/config', 'r') as f:
    text = f.read()
text = re.sub(r'certificate-authority-data: [^\n]+\n', '', text)
text = re.sub(r'(server: https://host.docker.internal:[0-9]+)', r'\1\n    insecure-skip-tls-verify: true', text)
with open('$SCRIPT_DIR/.kube/config', 'w') as f:
    f.write(text)
"
  echo "Kubeconfig copied and configured."
else
  echo "Warning: No ~/.kube/config found. Jenkins will not have cluster credentials."
fi

# Create a volume for Jenkins persistence
docker volume create jenkins_home || true

# Stop and remove existing container if it exists
if docker ps -a --format '{{.Names}}' | grep -q "^piggymetrics-jenkins$"; then
  echo "Stopping and removing existing piggymetrics-jenkins container..."
  docker rm -f piggymetrics-jenkins
fi

echo "Starting Jenkins container..."
docker run -d \
  --name piggymetrics-jenkins \
  -p 8080:8080 \
  -p 50000:50000 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v jenkins_home:/var/jenkins_home \
  -v "$SCRIPT_DIR/.kube:/root/.kube:ro" \
  -v "$WORKSPACE_DIR:/workspace" \
  -e HOST_WORKSPACE_DIR="$WORKSPACE_DIR" \
  --add-host host.docker.internal:host-gateway \
  piggymetrics-jenkins

echo "=========================================="
echo "Jenkins is starting up!"
echo "Access it at: http://localhost:8080"
echo "=========================================="
echo "To get the initial administrator password, run:"
echo "docker exec piggymetrics-jenkins cat /var/jenkins_home/secrets/initialAdminPassword"
echo "=========================================="
