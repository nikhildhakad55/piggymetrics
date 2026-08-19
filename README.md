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
