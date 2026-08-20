# PiggyMetrics: GitOps CI/CD with GitHub Actions & Argo CD

Welcome to the modernized DevOps deployment guide for **PiggyMetrics**. The application has been restructured to use a modular GitOps architecture with independent GitHub Actions workflows and Argo CD deployment management on a local Kubernetes (Kind) cluster.

---

## 🏗️ GitOps CI/CD Workflow Pipeline

Below is the automated GitOps and CI/CD workflow implemented for the microservices:

```
┌──────────────┐
│   Developer  │
└──────┬───────┘
       │ git push
       ▼
┌──────────────┐
│    GitHub    │
└──────┬───────┘
       │
       ▼
┌──────────────────────────┐
│     GitHub Actions       │
│                          │
│ Test                     │
│ Build                    │
│ Trivy                    │
│ Push                     │
└────────────┬─────────────┘
             │
             ▼
       ┌───────────┐
       │   GHCR    │
       │           │
       │ image:v1  │
       └─────┬─────┘
             │
             ▼
       ┌─────────────┐
       │  GitOps     │
       │ Repository  │
       └──────┬──────┘
              │
              ▼
          ┌─────────┐
          │ Argo CD │
          └────┬────┘
               │
               ▼
       ┌─────────────────┐
       │ Local Kubernetes│
       │     kind        │
       └─────────────────┘
```

---

## 📋 Implementation Plan & Key Features

### 1. Independent Workflows (CI/CD)
Each of the 4 microservices has its own independent, path-triggered GitHub Actions workflow file under `.github/workflows/`:
* `auth-service.yml`
* `account-service.yml`
* `statistics-service.yml`
* `notification-service.yml`

Workflows are triggered **only** when changes occur in their respective source directory or workflow file. Each workflow performs:
1. **Build**: Compiles the code using JDK 8 and Maven.
2. **Scan**: Runs Trivy scanner to check for vulnerabilities.
3. **Publish**: Builds a Docker container and pushes it to **GitHub Container Registry (GHCR)** at `ghcr.io/nikhildhakad55/piggymetrics-<service>:latest`.

### 2. Restructured Kubernetes Layout
To support GitOps and modularity, the `kubernetes` manifests are organized into clean subdirectories:
* **`kubernetes/infra/`** — Shared infrastructure and routing:
  * `k8s-secrets.yaml`
  * `rabbitmq.yaml`
  * `mongodb.yaml`
  * `infrastructure-services.yaml` (Eureka Registry, Config Server, Turbine, Monitoring)
  * `gateway.yaml` (Simplified single deployment for PiggyMetrics gateway using the original gateway image)
* **`kubernetes/apps/<service-name>/`** — Independent application manifests containing the standard service and single deployment configurations.

### 3. GitOps Argo CD Setup
Instead of a monolithic single application, Argo CD manages **5 separate Applications** declared in a multi-document manifest:
* `piggymetrics-infra` pointing to `kubernetes/infra`
* `piggymetrics-auth-service` pointing to `kubernetes/apps/auth-service`
* `piggymetrics-account-service` pointing to `kubernetes/apps/account-service`
* `piggymetrics-statistics-service` pointing to `kubernetes/apps/statistics-service`
* `piggymetrics-notification-service` pointing to `kubernetes/apps/notification-service`

---

## 🚀 Quick Start Guide

### 1. Prerequisites
Ensure you have the following installed on your host system:
* **Docker**
* **Kind**
* **kubectl**

### 2. Cluster & Argo CD Bootstrapping
1. Spin up the Kind cluster:
   ```bash
   kind create cluster --name piggymetrics --config scripts/kind-config.yaml
   ```
2. Install Argo CD to the cluster:
   ```bash
   kubectl create namespace argocd || true
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --server-side
   ```

### 3. Deploying the Environment
1. Apply the Secrets and RabbitMQ manifests manually to bootstrap connectivity:
   ```bash
   kubectl apply -f kubernetes/infra/k8s-secrets.yaml
   kubectl apply -f kubernetes/infra/rabbitmq.yaml
   ```
2. Apply the multi-app Argo CD configuration:
   ```bash
   kubectl apply -f kubernetes/argocd-apps.yaml
   ```
3. Open the Argo CD Dashboard or check status with:
   ```bash
   kubectl get applications -n argocd
   kubectl get pods -n piggymetrics
   ```

---

## 🔌 How Argo CD Connects (Under the Hood)

### 1. Connection to GitHub (Source)
Argo CD runs an internal service called `argocd-repo-server` that polls the Git repository at `https://github.com/nikhildhakad55/piggymetrics.git` once every 3 minutes.
* **Public Repository**: Since this repository is public, Argo CD connects using read-only HTTPS without requiring credentials.
* **Private Repository**: If the Git repository were private, Argo CD would connect using one of these options:
  1. **SSH Private Key**: Registering a Deploy Key in the GitHub repository settings and uploading the private SSH key to Argo CD.
  2. **HTTPS with Credentials**: Configuring a Personal Access Token (PAT) as the password along with the GitHub username.

### 2. Connection to Local Kubernetes (Destination)
* **Internal Credentials**: Because Argo CD is installed inside the cluster itself, it does not need password/token configurations to communicate with Kubernetes. It uses an internal Kubernetes **Service Account** with administrator cluster-role permissions.
* **Manifest Application**: When Argo CD detects changes in Git, it securely calls the Kubernetes API Server (acting similarly to an automated `kubectl apply` process) to update the Deployment resources.

---

## 🚀 Future Roadmap: Argo Workflows & Istio Canary Deployments

We are planning an enterprise-grade architecture shift to replace GitHub Actions with **Argo Workflows** and introduce **Istio** for Canary deployments.

### 1. Argo Events & Argo Workflows (CI Replacement)
Instead of GitHub Actions, we will install **Argo Workflows** and **Argo Events** directly in the Kubernetes cluster.

* **Path-Triggered Execution**: We will set up an EventSource (GitHub Webhook) and a Sensor that checks which files changed. If a specific folder (e.g., `account-service/`) changes, the Sensor triggers only the corresponding Argo Workflow.
* **Workflow Steps**: Checkout -> Build -> Trivy Scan -> Push to GHCR -> **Commit the new Image SHA back to the Git Repository**.

### 2. Istio Canary Deployments (CD Enhancement)
To support a Canary release flow (`Stable` vs `Canary`):
* We will install **Istio** in the cluster.
* When Argo CD syncs the new image tag (updated by the Argo Workflow), Istio will route a small percentage of traffic (e.g., 10%) to the new "Canary" pods before a full rollout.

### 3. Argo Workflows & Argo Events Installation Log
To start the implementation of the future roadmap, we executed the following steps to install Argo Workflows and Argo Events on the cluster:

#### Installing Argo Workflows
We deployed the Argo Workflows controller and server into a new `argo` namespace using these commands:
```bash
kubectl create namespace argo
kubectl apply -n argo -f https://github.com/argoproj/argo-workflows/releases/download/v3.4.11/install.yaml
```

#### Installing Argo Events
We deployed the Argo Events components into a new `argo-events` namespace. These components (EventBus, EventSource, Sensor) are what we will use to listen for GitHub Webhooks and conditionally trigger your service pipelines based on which folders changed:
```bash
kubectl create namespace argo-events
kubectl apply -n argo-events -f https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install.yaml
```

### 4. Next Steps for Argo Workflows Integration
To fully replace GitHub Actions and achieve the path-triggered pipelines we requested, we will need to create the following components:

1. **An EventBus**: The message queue for Argo Events.
2. **A GitHub EventSource**: An endpoint in our cluster that receives Webhooks from GitHub when we run `git push`.
3. **A Sensor with Trigger Filters**: This component evaluates the GitHub push payload (specifically the list of added, modified, and removed files) and conditionally triggers the specific Argo Workflow (e.g., `account-service-workflow`) if files in the `account-service/` folder changed.
4. **The Argo Workflows**: The Kubernetes-native workflow templates that will checkout code, build with Maven, scan with Trivy, build the Docker image, and push it to GHCR.
