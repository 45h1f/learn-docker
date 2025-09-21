# Learning Guide: Docker to Enterprise

Follow this path end-to-end. Each step references folders in this repo with demos and exercises.

## 0) Environment
- Complete `docs/ENVIRONMENT-SETUP.md` and ensure `docker`, `kubectl`, and (optionally) a local K8s cluster are ready.

## 1) Core Docker (Modules 1–3)
- `01-fundamentals/`: containers, images, volumes, bind mounts, lifecycle.
  - Try: `docker run -it --rm alpine:3.20 sh`, `docker ps`, `docker logs`, `docker exec`.
- `02-images-best-practices/`: Dockerfile, multi-stage, caching, size reduction.
  - Try: Convert an app to a multi-stage build; compare `docker images` sizes.
- `03-compose-orchestration/`: Compose services, networks, env, profiles.
  - Try: `docker compose up -d`; add an env override file; switch profiles.

## 2) Ops & Production (Modules 4–6)
- `04-networking-storage/`: network types, name resolution, volumes, persistence.
  - Try: Custom network + two containers ping by name; volume-backed DB.
- `05-security-compliance/`: users, capabilities, secrets, scanning, policies.
  - Try: Run as non-root; mount a secret; run Trivy scan on your images.
- `06-production-deployment/`: health checks, blue/green, rolling updates.
  - Try: Implement health endpoints; simulate blue/green with two tags.

## 3) Docker Hub & CI (Module 7)
- `07-registries-cicd/` and `docs/docker-hub-guide.md`.
  - Try: `docker login`; tag/push; promote by tag; basic GH Actions pipeline.
  - Stretch: Multi-arch build with Buildx; add scan gate with Trivy.

## 4) Kubernetes (Module 8)
- `08-kubernetes-integration/`: migrate from Compose; deployments, services, ingress.
  - Try: `./08-kubernetes-integration/demo.sh`; scale deployments; HPA.
  - Stretch: StatefulSet demo; enable Istio (if installed); add network policies.

## 5) Performance & Troubleshooting (Module 9)
- `09-performance-troubleshooting/`: demos for monitoring, debugging, tracing.
  - Try: `./09-performance-troubleshooting/demo.sh`; set up Prometheus/Grafana.
  - Stretch: Add Jaeger tracing and correlate with metrics.

## 6) Enterprise Patterns (Module 10)
- `10-enterprise-architecture/`: microservices, gateway/BFF, Istio traffic.
  - Try: `./10-enterprise-architecture/demo.sh build-push <dockerhub-username>` then `deploy-k8s <dockerhub-username>`.
  - Stretch: Canary/blue-green with Istio; implement saga/outbox from exercises.

## 7) Supply Chain Security Pack
- Read `05-security-compliance/supply-chain.md`.
  - Try (local): `./scripts/supply-chain-demo.sh <dockerhub-username>/app v1`.
  - Enforce: Paste your cosign pubkey in `05-security-compliance/policies/kyverno/verify-signed-images.yaml` and apply.
  - CI: Add GitHub secrets and run `.github/workflows/supply-chain.yml`.

## 8) Capstone Project
- Build a small microservices app (web + API + DB + cache) and apply:
  - Docker Hub images and CI
  - K8s deployment with HPA and probes
  - Observability (Grafana/Prometheus, logs, tracing)
  - Supply chain (SBOM, scan, sign, Kyverno policy)

## 9) Certification Prep
- DCA: Docker commands, images, Compose, registries, security basics.
- CKA/CKAD: K8s resources, networking, storage, autoscaling, RBAC, troubleshooting.
- Use Module 8–9 exercises as timed labs.

## Timeboxed Plan
- Week 1: Modules 1–3
- Week 2: Modules 4–6
- Week 3: Module 7 + 8
- Week 4: Module 9 + 10 + Supply Chain + Capstone start

You’re set. Start at `01-fundamentals/` and follow the steps; use this guide as your checklist.
