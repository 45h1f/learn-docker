#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
msg(){ echo -e "${BLUE}==> ${1}${NC}"; }
warn(){ echo -e "${YELLOW}==> ${1}${NC}"; }
err(){ echo -e "${RED}xx ${1}${NC}"; }

check(){
  command -v docker >/dev/null || { err "docker required"; exit 1; }
  command -v kubectl >/dev/null || warn "kubectl not found; k8s parts will be skipped";
}

build_and_push(){
  local dh_user="${1:-}"
  if [[ -z "${dh_user}" ]]; then err "Usage: build_and_push <dockerhub-username>"; exit 1; fi
  msg "Building sample api/web and pushing to Docker Hub: ${dh_user}"
  tmpdir=$(mktemp -d); pushd "$tmpdir" >/dev/null

  mkdir -p api web
  cat > api/app.py <<'EOF'
from flask import Flask
app = Flask(__name__)
@app.get('/')
def root(): return {'service':'api'}
if __name__=='__main__': app.run(host='0.0.0.0',port=5000)
EOF
  cat > api/Dockerfile <<'EOF'
FROM python:3.11-slim
WORKDIR /app
RUN pip install flask gunicorn
COPY app.py .
EXPOSE 5000
CMD ["gunicorn","-w","2","-b","0.0.0.0:5000","app:app"]
EOF

  cat > web/server.js <<'EOF'
const express=require('express');
const app=express();
app.get('/',(req,res)=>res.json({service:'web'}));
app.listen(3000,()=>console.log('web on 3000'));
EOF
  cat > web/package.json <<'EOF'
{ "name":"web","version":"1.0.0","dependencies":{"express":"^4.18.2"} }
EOF
  cat > web/Dockerfile <<'EOF'
FROM node:20-alpine
WORKDIR /app
COPY package.json .
RUN npm ci --silent || npm i --silent
COPY . .
EXPOSE 3000
CMD ["node","server.js"]
EOF

  docker build -t "$dh_user/ea10-api:v1" api
  docker build -t "$dh_user/ea10-web:v1" web
  docker login
  docker push "$dh_user/ea10-api:v1"
  docker push "$dh_user/ea10-web:v1"

  popd >/dev/null; rm -rf "$tmpdir"
  msg "Pushed images to Docker Hub"
}

deploy_k8s(){
  local dh_user="${1:-}"; [[ -z "$dh_user" ]] && { err "Usage: deploy_k8s <dockerhub-username>"; exit 1; }
  if ! kubectl cluster-info >/dev/null 2>&1; then warn "No cluster; skipping k8s"; return; fi
  msg "Deploying to Kubernetes from Docker Hub images"
  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata: { name: ea10 }
---
apiVersion: apps/v1
kind: Deployment
metadata: { name: api, namespace: ea10 }
spec:
  replicas: 2
  selector: { matchLabels: { app: api } }
  template:
    metadata: { labels: { app: api } }
    spec:
      containers:
      - name: api
        image: ${dh_user}/ea10-api:v1
        ports: [{ containerPort: 5000 }]
---
apiVersion: v1
kind: Service
metadata: { name: api, namespace: ea10 }
spec:
  selector: { app: api }
  ports: [{ port: 5000, targetPort: 5000 }]
---
apiVersion: apps/v1
kind: Deployment
metadata: { name: web, namespace: ea10 }
spec:
  replicas: 2
  selector: { matchLabels: { app: web } }
  template:
    metadata: { labels: { app: web } }
    spec:
      containers:
      - name: web
        image: ${dh_user}/ea10-web:v1
        env: [{ name: API_URL, value: http://api.ea10.svc.cluster.local:5000 }]
        ports: [{ containerPort: 3000 }]
---
apiVersion: v1
kind: Service
metadata: { name: web, namespace: ea10 }
spec:
  selector: { app: web }
  ports: [{ port: 3000, targetPort: 3000 }]
EOF
  kubectl -n ea10 rollout status deploy/api
  kubectl -n ea10 rollout status deploy/web
  msg "Deployed. Port-forwarding web to localhost:9300"
  kubectl -n ea10 port-forward svc/web 9300:3000 >/dev/null 2>&1 & echo $! > /tmp/ea10.pf
  sleep 3
  curl -s http://localhost:9300 | jq . || curl -s http://localhost:9300
}

istio_demo(){
  if ! kubectl get ns istio-system >/dev/null 2>&1; then warn "Istio not detected; skipping"; return; fi
  msg "Applying Istio traffic policies (timeouts/retries)"
  cat <<'EOF' | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata: { name: api-dr, namespace: ea10 }
spec:
  host: api.ea10.svc.cluster.local
  trafficPolicy:
    connectionPool:
      tcp: { maxConnections: 100 }
      http: { http1MaxPendingRequests: 1000, maxRequestsPerConnection: 100 }
    outlierDetection:
      consecutive5xxErrors: 3
      interval: 5s
      baseEjectionTime: 30s
    tls: { mode: ISTIO_MUTUAL }
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata: { name: api-vs, namespace: ea10 }
spec:
  hosts: ["api.ea10.svc.cluster.local"]
  http:
  - timeout: 2s
    retries: { attempts: 3, perTryTimeout: 500ms }
    route:
    - destination: { host: api.ea10.svc.cluster.local, subset: v1 }
EOF
}

cleanup(){
  msg "Cleaning up"
  if [[ -f /tmp/ea10.pf ]]; then kill $(cat /tmp/ea10.pf) 2>/dev/null || true; rm -f /tmp/ea10.pf; fi
  kubectl delete ns ea10 2>/dev/null || true
}

usage(){
  cat <<USAGE
Usage:
  $0 build-push <dockerhub-username>
  $0 deploy-k8s <dockerhub-username>
  $0 istio
  $0 cleanup
USAGE
}

main(){
  check
  sub=${1:-help}
  case "$sub" in
    build-push) shift; build_and_push "${1:-}" ;;
    deploy-k8s) shift; deploy_k8s "${1:-}" ;;
    istio) istio_demo ;;
    cleanup) cleanup ;;
    *) usage ;;
  esac
}
main "$@"
