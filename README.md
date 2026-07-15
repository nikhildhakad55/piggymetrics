# DevOps Assessment: Kubernetes, Jenkins CI/CD & Blue-Green Deployment

Welcome to the Kubernetes and CI/CD deployment guide for **PiggyMetrics**. This project has been migrated from a Docker Compose local environment to a fully automated local Kubernetes (Kind) environment with a containerized Jenkins CI/CD pipeline and a Kubernetes-native Blue-Green deployment strategy.

---

## Architecture and Design Document

For a detailed view of the system architecture, Eureka-bypass routing, and Blue-Green sequence flows, please refer to the [blue-green-design.md](blue-green-design.md) file.

---

## 🚀 Quick Start Guide

### 1. Prerequisites
Ensure you have the following installed on your host system:
* **Docker Desktop** (running and allocated with at least 4GB RAM)
* **Homebrew** (for macOS package management)

### 2. Kubernetes Cluster Setup (Kind)
We use Kind (Kubernetes in Docker) to run a local cluster. The setup script will automatically install `kind` if it is missing, create a cluster named `piggymetrics`, configure local port forwarding, and set your `kubectl` context.

Run the following command:
```bash
./scripts/setup-kind-cluster.sh
```

**What this does**:
* Installs `kind` via Homebrew if not present.
* Spins up a Kubernetes control-plane container.
* Maps port `80` on your host to NodePort `30080` (API Gateway).
* Maps port `8761` on your host to NodePort `30761` (Eureka Dashboard).
* Maps port `9000` on your host to NodePort `30900` (Hystrix Monitoring).
* Sets the namespace context to `piggymetrics`.

---

## 📦 Deploying the Application

### 1. Create Secrets and Databases
Run the following to deploy the Kubernetes Secrets, RabbitMQ message broker, and the 4 MongoDB databases:
```bash
kubectl apply -f kubernetes/k8s-secrets.yaml
kubectl apply -f kubernetes/rabbitmq.yaml
kubectl apply -f kubernetes/mongodb.yaml
```

### 2. Deploy Infrastructure & Functional Services
Deploy the remaining Spring Cloud infrastructure and the initial (blue) version of the functional microservices:
```bash
kubectl apply -f kubernetes/infrastructure-services.yaml
kubectl apply -f kubernetes/functional-services-bluegreen.yaml
```

### 3. Verify Deployment
Monitor the pods until they are all in the `Running` state and show `1/1` readiness:
```bash
kubectl get pods
```

You can access the services locally at:
* **Gateway (UI)**: [http://localhost:80](http://localhost:80) (Default login: `demo`/`demo` or register a new user)
* **Eureka Registry Dashboard**: [http://localhost:8761](http://localhost:8761)
* **Hystrix Dashboard**: [http://localhost:9000](http://localhost:9000)

---

## 🛠️ Jenkins CI/CD Pipeline

We run a containerized Jenkins instance that has the Docker CLI and `kubectl` client pre-installed, allowing it to compile Java code, build and push images to your Docker Hub registry, and deploy them to the local Kind cluster.

### 1. Start Jenkins Container
Run the bootstrap script to build the custom Jenkins image and start the container:
```bash
./scripts/run-jenkins.sh
```

### 2. Retrieve Initial Admin Password
Wait a moment for Jenkins to start, then run:
```bash
docker exec piggymetrics-jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```
Open [http://localhost:8080](http://localhost:8080) in your browser and enter the password to complete the setup. Choose **"Install suggested plugins"**.

### 3. Configure Docker Hub Credentials
To allow Jenkins to push images to Docker Hub:
1. Navigate to **Manage Jenkins** -> **Credentials** -> **System** -> **Global credentials**.
2. Click **Add Credentials**.
3. Select **Username with password** as the kind.
4. Set the **ID** to exactly `docker-hub-credentials`.
5. Enter your Docker Hub Username and Password/Token.
6. Click **Save**.

### 4. Create Jenkins Pipelines
Create a Pipeline job for any of the microservices (e.g. `account-service`):
1. On the home page, click **New Item**.
2. Name it `account-service` and select **Pipeline**. Click **OK**.
3. Under **Build Triggers**, select trigger options if desired.
4. Under **Pipeline Definition**, select **Pipeline script from SCM**.
5. Set SCM to **Git** and Repository URL to your repository path (e.g., `/workspace` or your GitHub URL).
6. Set Script Path to the service's Jenkinsfile: `account-service/Jenkinsfile`.
7. Click **Save** and trigger a **Build Now**.

---

## 🔵🟢 Blue-Green Deployment & Rollback

### Manual Execution
The Blue-Green deployment logic is entirely orchestrated by `scripts/deploy-blue-green.sh`. 

To run it manually:
```bash
./scripts/deploy-blue-green.sh <service-name> <image-tag> [docker-hub-username]
```
For example, to deploy tag `v2` of `account-service` using the Docker Hub user `myuser`:
```bash
./scripts/deploy-blue-green.sh account-service v2 myuser
```

### Automatic Rollback
If the deployment of the new color fails to start or fails readiness checks (e.g. timeout of 180 seconds):
1. The script will **not** switch the service selector, keeping all live traffic on the current healthy version.
2. The script will scale down the failed target deployment to `0` replicas to free up resources.
3. The build job in Jenkins will fail, signaling a failed release.

---

## Original PiggyMetrics Documentation

Below is the original documentation for the application, outlining its functionality, business domains, and original Docker Compose settings.

*(For detailed configurations, see original files in the repository).*
