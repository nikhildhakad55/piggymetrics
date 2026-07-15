FROM jenkins/jenkins:lts
USER root

# Install Docker CLI, curl, and maven from Debian main repositories
RUN apt-get update && apt-get install -y docker.io curl maven

# Install kubectl matching the container's native architecture (amd64 or arm64)
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/$(dpkg --print-architecture)/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/

# Keep root user to ensure Jenkins has permission to read/write host mounts (like docker.sock and kubeconfig)
USER root
