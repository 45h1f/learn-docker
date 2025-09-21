# Docker Hub Guide (Enterprise Best Practices)

## Login and Tokens
- Use access tokens instead of passwords. Rotate regularly.
- Login from CLI:
```bash
docker login
```
- For CI: store token as secret (e.g., `DOCKERHUB_TOKEN`) and username as `DOCKERHUB_USERNAME`.

## Tagging Strategy
- Semantic versioning: `v1.2.3`, with moving tags: `v1.2`, `v1`, `latest`.
- Include build metadata or commit SHA: `v1.2.3-<shortsha>`.
- Avoid mutable `latest` in production deploys; pin immutable tags or digests.

## Build, Tag, Push
```bash
export DH_USER=<your-username>
docker build -t $DH_USER/app:v1 .
docker push $DH_USER/app:v1
# Promote by retagging (immutable base):
docker pull $DH_USER/app:v1
docker tag $DH_USER/app:v1 $DH_USER/app:prod
docker push $DH_USER/app:prod
```

## Organizations and Teams
- Create orgs for companies; use teams for RBAC.
- Grant least privilege push/pull per repo.
- Use private repos for internal images.

## Content Trust and Signing
- Enable Docker Content Trust for pull-time verification:
```bash
export DOCKER_CONTENT_TRUST=1
```
- Prefer Sigstore Cosign for signing and provenance:
```bash
cosign generate-key-pair
cosign sign $DH_USER/app:v1
cosign verify $DH_USER/app:v1
```

## Security Scanning
- Enable Docker Hub scanning or use Trivy locally/CI:
```bash
trivy image $DH_USER/app:v1
```
- Block releases on high/critical vulnerabilities.

## Rate Limits and Caching
- Use authenticated pulls to increase limits.
- Configure a registry mirror/cache (Harbor/Artifactory) for CI speed and resilience.

## CI/CD Examples

### GitHub Actions
```yaml
name: build-and-push
on:
  push:
    branches: [ main ]
jobs:
  docker:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
    - uses: actions/checkout@v4
    - uses: docker/setup-buildx-action@v3
    - uses: docker/login-action@v3
      with:
        username: ${{ secrets.DOCKERHUB_USERNAME }}
        password: ${{ secrets.DOCKERHUB_TOKEN }}
    - uses: docker/build-push-action@v6
      with:
        context: .
        push: true
        tags: ${{ secrets.DOCKERHUB_USERNAME }}/app:latest,${{ secrets.DOCKERHUB_USERNAME }}/app:${{ github.sha }}
```

### GitLab CI
```yaml
build_push:
  image: docker:24-git
  services: [ docker:24-dind ]
  variables:
    DOCKER_TLS_CERTDIR: "/certs"
  script:
    - echo "$CI_REGISTRY_PASSWORD" | docker login -u "$CI_REGISTRY_USER" --password-stdin
    - docker build -t $CI_REGISTRY_USER/app:$CI_COMMIT_SHORT_SHA .
    - docker push $CI_REGISTRY_USER/app:$CI_COMMIT_SHORT_SHA
  only: [ main ]
```

## Pull Secrets in Kubernetes
```yaml
apiVersion: v1
kind: Secret
metadata: { name: regcred }
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: <base64-encoded-config.json>
---
apiVersion: apps/v1
kind: Deployment
metadata: { name: app }
spec:
  template:
    spec:
      imagePullSecrets: [{ name: regcred }]
```

## Promotion Flow
- Build once, tag immutably (commit SHA), push to Docker Hub.
- Promote by tag (e.g., `:staging` -> `:prod`) after tests.
- Keep SBOMs and attestations (Syft/Grype + Cosign) alongside images.

## Troubleshooting
- 401: re-login or token revoked.
- Rate limit: authenticate, use mirror, or reduce anonymous pulls.
- Pull failures in cluster: configure `imagePullSecrets` and verify network/DNS.
