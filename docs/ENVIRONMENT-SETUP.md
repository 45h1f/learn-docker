# Environment Setup (Linux)

Prepare a reliable local environment for Docker, Kubernetes, security tools, and CI-adjacent utilities. Commands assume bash and sudo access.

## 1) Docker Engine
```bash
# Install Docker Engine (Ubuntu/Debian)
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Post-install (optional)
sudo usermod -aG docker $USER
newgrp docker

# Verify
docker --version
docker run --rm hello-world
```

## 2) kubectl
```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/
kubectl version --client
```

## 3) Local Kubernetes (choose one)
- Minikube:
```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
minikube start --driver=docker
kubectl get nodes
```
- kind:
```bash
curl -Lo kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64
chmod +x kind && sudo mv kind /usr/local/bin/
kind create cluster --name docker-lean
kubectl cluster-info --context kind-docker-lean
```

## 4) Helm (optional)
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

## 5) Istio (optional)
```bash
curl -L https://istio.io/downloadIstio | sh -
cd istio-*/bin && sudo mv istioctl /usr/local/bin/ && cd -
istioctl version
# Install demo profile (minikube/kind)
istioctl install -y --set profile=demo
kubectl label namespace default istio-injection=enabled --overwrite
```

## 6) Security Tooling
- Trivy
```bash
sudo apt-get install -y wget
wget https://github.com/aquasecurity/trivy/releases/latest/download/trivy_0.50.0_Linux-64bit.deb
sudo dpkg -i trivy_0.50.0_Linux-64bit.deb
trivy --version
```
- Syft & Grype
```bash
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sudo sh -s -- -b /usr/local/bin
curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sudo sh -s -- -b /usr/local/bin
syft version
grype version
```
- Cosign
```bash
COSIGN_URL=$(curl -s https://api.github.com/repos/sigstore/cosign/releases/latest | grep browser_download_url | grep linux-amd64 | cut -d '"' -f 4)
curl -L "$COSIGN_URL" -o cosign && chmod +x cosign && sudo mv cosign /usr/local/bin/
cosign version
```

## 7) Buildx + QEMU
```bash
# Buildx comes with recent Docker; ensure a builder is available
docker buildx version
docker buildx create --name devbuilder --use || docker buildx use devbuilder
# QEMU (for multi-arch emulation)
docker run --privileged --rm tonistiigi/binfmt --install all
```

## 8) Docker Hub Login
```bash
docker login
```

## 9) Quick Sanity Checks
```bash
# Docker
docker run --rm alpine:3.20 echo OK

# Kubernetes (if running)
kubectl get ns

# Buildx
docker buildx ls

# Trivy on a base image
trivy image alpine:3.20 | head -n 20
```

You’re ready to start at `01-fundamentals/` and follow the Learning Guide.
