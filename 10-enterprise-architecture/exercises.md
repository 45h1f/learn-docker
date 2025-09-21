# Module 10: Enterprise Architecture Patterns — Exercises

## Overview
These exercises reinforce microservices, service mesh, distributed systems patterns, and enterprise integration using Docker, Kubernetes, and Docker Hub.

## Prerequisites
- Completed Modules 1–9
- Kubernetes cluster (kind/minikube/managed)
- kubectl, Helm, and Docker Hub account

---

## Exercise 1: Microservices Decomposition with Docker Hub

### Objective
Decompose a monolith into two microservices, build images, push to Docker Hub, and deploy.

### Steps
1. Create services
```bash
mkdir -p services/api services/web
```

`services/api/app.py`
```python
from flask import Flask, jsonify
app = Flask(__name__)

@app.get('/api/products')
def products():
    return jsonify([{"id": 1, "name": "Widget"}, {"id": 2, "name": "Gadget"}])

@app.get('/health')
def health():
    return {"status": "ok"}

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```

`services/api/Dockerfile`
```dockerfile
FROM python:3.11-slim
WORKDIR /app
RUN pip install flask gunicorn
COPY app.py .
EXPOSE 5000
CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:5000", "app:app"]
```

`services/web/server.js`
```js
const express = require('express');
const fetch = (...args) => import('node-fetch').then(({default: fetch}) => fetch(...args));
const app = express();
const API_URL = process.env.API_URL || 'http://localhost:5000';

app.get('/', async (req, res) => {
  try {
    const r = await fetch(`${API_URL}/api/products`);
    const items = await r.json();
    res.json({ service: 'web', items });
  } catch (e) {
    res.status(500).json({ error: e.toString() });
  }
});

app.get('/health', (req, res) => res.json({ status: 'ok' }));

app.listen(3000, () => console.log('web listening on 3000'));
```

`services/web/package.json`
```json
{ "name":"web","version":"1.0.0","dependencies":{"express":"^4.18.2","node-fetch":"^3.3.2"} }
```

`services/web/Dockerfile`
```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package.json .
RUN npm ci --silent || npm i --silent
COPY . .
EXPOSE 3000
CMD ["node","server.js"]
```

2. Build, tag, and push to Docker Hub
```bash
# Set your Docker Hub repo prefix
export DH_USER="<your-dockerhub-username>"

# Login once
docker login

# Build images
docker build -t "$DH_USER/ea10-api:v1" services/api
docker build -t "$DH_USER/ea10-web:v1" services/web

# Push
docker push "$DH_USER/ea10-api:v1"
docker push "$DH_USER/ea10-web:v1"
```

3. Deploy with Compose (local) or Kubernetes (cluster)
```yaml
# docker-compose.yaml
version: "3.9"
services:
  api:
    image: ${DH_USER}/ea10-api:v1
    ports: ["5000:5000"]
  web:
    image: ${DH_USER}/ea10-web:v1
    environment:
      - API_URL=http://api:5000
    ports: ["3000:3000"]
    depends_on: [api]
```

```bash
# Local run
export DH_USER="<your-dockerhub-username>"
docker compose up -d
curl -s http://localhost:3000 | jq
```

Kubernetes manifests using images from Docker Hub:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata: { name: api }
spec:
  replicas: 2
  selector: { matchLabels: { app: api } }
  template:
    metadata: { labels: { app: api } }
    spec:
      containers:
      - name: api
        image: <your-dockerhub-username>/ea10-api:v1
        ports: [{ containerPort: 5000 }]
---
apiVersion: v1
kind: Service
metadata: { name: api }
spec:
  selector: { app: api }
  ports: [{ port: 5000, targetPort: 5000 }]
---
apiVersion: apps/v1
kind: Deployment
metadata: { name: web }
spec:
  replicas: 2
  selector: { matchLabels: { app: web } }
  template:
    metadata: { labels: { app: web } }
    spec:
      containers:
      - name: web
        image: <your-dockerhub-username>/ea10-web:v1
        env: [{ name: API_URL, value: http://api:5000 }]
        ports: [{ containerPort: 3000 }]
---
apiVersion: v1
kind: Service
metadata: { name: web }
spec:
  selector: { app: web }
  ports: [{ port: 3000, targetPort: 3000 }]
```

Validation:
- `curl http://web:3000` returns items
- Scale replicas and verify load distribution

---

## Exercise 2: API Gateway and BFF
Implement Kong or NGINX as API gateway, add a BFF layer for web/mobile, and secure with JWT. Include rate limiting, request/response transforms, and per-route metrics.

---

## Exercise 3: Resilience Patterns with Istio
Implement retries, timeouts, circuit breakers, and outlier detection with DestinationRule/VirtualService. Add mTLS and RBAC.

---

## Exercise 4: Data Patterns (Saga + Outbox)
Model an order workflow using Saga (orchestration or choreography). Use an Outbox table + Debezium/Kafka to reliably publish events.

---

## Exercise 5: Event-Driven Architecture with Kafka
Provision Kafka (e.g., Bitnami Helm), implement producers/consumers in separate services, and model DLQ for poison messages. Visualize lag and throughput in Grafana.

---

## Exercise 6: Multi-Cloud/Hybrid Strategy
Design deployment for two clusters (different clouds or regions) with global traffic management (Cloud DNS/GSLB). Implement read replicas and DR plan (RPO/RTO targets).

---

## Deliverables
- Docker Hub images and tags strategy (semver, build metadata)
- Manifests/Helm charts with imagePullSecrets as needed
- Gateway/mesh policies and dashboards
- Runbooks for failure modes and rollbacks

## Checklist
- Images built with multi-stage and scanned
- SBOM and signatures (cosign) stored
- Provenance attestations (SLSA basics)
- Secrets via external secret store (Vault/ASM/SM)
- Observability with traces/metrics/logs
