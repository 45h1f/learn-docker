# Supply Chain Security Pack

Harden your image pipeline with SBOM generation, vulnerability scanning, image signing, and policy enforcement. This guide uses Syft/Grype, Docker Scout, Cosign, and Kyverno.

## Tools
- Syft (SBOM), Grype (scanner)
- Docker Scout (advisories + policy)
- Cosign (sign/verify + attestations)
- Kyverno (Kubernetes policy) or Gatekeeper/Connaisseur alternatives

## Install (local)
```bash
# Syft/Grype
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sudo sh -s -- -b /usr/local/bin
curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sudo sh -s -- -b /usr/local/bin
# Cosign
curl -sSfL https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64 \
  -o /usr/local/bin/cosign && sudo chmod +x /usr/local/bin/cosign
# Docker Scout (Docker CLI plugin comes with modern Docker Desktop/Engine)
docker scout --help || true
```

## Workflow Overview
1. Build multi-arch image with Buildx
2. Generate SBOM (store in repo or OCI attestation)
3. Scan vulnerabilities (Grype/Scout) and enforce thresholds
4. Sign image and/or attestations (Cosign keyless or key pair)
5. Enforce signature policy in Kubernetes (Kyverno)

## Build Multi-Arch Image (with cache)
```bash
export IMAGE="$DOCKERHUB_USERNAME/app"
export TAG="v1"

docker buildx create --use --name scx || docker buildx use scx
# optional: warm cache from registry
# docker buildx build --cache-to=type=registry,ref=$IMAGE:buildcache,mode=max --cache-from=type=registry,ref=$IMAGE:buildcache \
#   -t $IMAGE:$TAG --platform linux/amd64,linux/arm64 --push .

docker buildx build -t $IMAGE:$TAG \
  --platform linux/amd64,linux/arm64 \
  --provenance=true --sbom=true \
  --push .
```

Notes:
- `--provenance` and `--sbom` embed attestations (requires BuildKit feature parity).
- For private repos, configure `docker login` first.

## SBOM Generation (Syft)
```bash
syft $IMAGE:$TAG -o table
syft $IMAGE:$TAG -o json > sbom.json
```

## Vulnerability Scanning
```bash
# Grype
grype $IMAGE:$TAG --fail-on high --only-fixed
# Docker Scout (requires auth)
docker scout cves $IMAGE:$TAG
```

## Signing and Verification (Cosign)
```bash
# Keyed
cosign generate-key-pair # creates cosign.key/.pub; store secrets safely
COSIGN_PASSWORD="" cosign sign -y $IMAGE:$TAG
cosign verify $IMAGE:$TAG --key cosign.pub

# Keyless (OIDC)
COSIGN_EXPERIMENTAL=1 cosign sign $IMAGE:$TAG
COSIGN_EXPERIMENTAL=1 cosign verify $IMAGE:$TAG
```

## Attestations (SLSA-style)
```bash
COSIGN_PASSWORD="" cosign attest -y --predicate sbom.json --type cyclonedx $IMAGE:$TAG
cosign verify-attestation $IMAGE:$TAG --type cyclonedx --key cosign.pub
```

## Kubernetes Policy Enforcement (Kyverno)
Require images to be signed by your public key.
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-signed-images
spec:
  validationFailureAction: Enforce
  rules:
    - name: require-cosign-signature
      match:
        resources:
          kinds: [Pod, Deployment, StatefulSet, DaemonSet, Job, CronJob]
      verifyImages:
        - imageReferences:
            - "docker.io/<your-org>/*"
          attestors:
            - entries:
                - keys:
                    publicKeys: |
                      -----BEGIN PUBLIC KEY-----
                      <paste-your-cosign.pub>
                      -----END PUBLIC KEY-----
```

## CI Gate (fail on vulns)
- Use Grype or Docker Scout policies to block merges/releases.
- Store SBOMs as build artifacts and/or attach via Cosign attestations.
- Promote only signed+scanned images.

## Cleanup and Rotation
- Rotate Cosign keys (if using key pairs); prefer keyless with OIDC where possible.
- Regularly re-scan images in registry (new CVEs after build time).
- Prune old tags; keep immutable digests for provenance.

## References
- Cosign: https://docs.sigstore.dev/cosign/overview
- Syft/Grype: https://anchore.com/opensource
- Docker Scout: https://docs.docker.com/scout/
- Kyverno: https://kyverno.io/
