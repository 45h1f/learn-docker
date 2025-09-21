#!/usr/bin/env bash
set -euo pipefail
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
msg(){ echo -e "${BLUE}==> ${1}${NC}"; }
err(){ echo -e "${RED}xx ${1}${NC}"; }

IMAGE="${1:-}"
TAG="${2:-v1}"
if [[ -z "$IMAGE" ]]; then err "Usage: $0 <dockerhub-username>/app [tag]"; exit 1; fi

# Minimal sample app
mkdir -p /tmp/sc-app && pushd /tmp/sc-app >/dev/null
cat > app.py <<'EOF'
from flask import Flask
app = Flask(__name__)
@app.get('/')
def root(): return { 'ok': True }
if __name__=='__main__': app.run(host='0.0.0.0', port=5000)
EOF
cat > Dockerfile <<'EOF'
FROM python:3.11-slim
WORKDIR /app
RUN pip install flask gunicorn
COPY app.py .
EXPOSE 5000
CMD ["gunicorn","-w","2","-b","0.0.0.0:5000","app:app"]
EOF

msg "Building image $IMAGE:$TAG"
docker build -t "$IMAGE:$TAG" .
msg "Pushing image"
docker login
docker push "$IMAGE:$TAG"

msg "Generating SBOM (syft)"
syft "$IMAGE:$TAG" -o json > sbom.json

msg "Scanning vulnerabilities (grype)"
grype "$IMAGE:$TAG" --fail-on high --only-fixed || true

msg "Signing image (cosign)"
COSIGN_PASSWORD="" cosign sign -y "$IMAGE:$TAG" || true

msg "Verifying signature"
cosign verify "$IMAGE:$TAG" --insecure-ignore-tlog || true

msg "Done. Artifacts: /tmp/sc-app/sbom.json"
popd >/dev/null
