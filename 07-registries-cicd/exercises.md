# Module 7: Container Registries & CI/CD - Exercises

## 🎯 Learning Objectives
By completing these exercises, you will:
- Set up and manage private Docker registries
- Implement complete CI/CD pipelines with Docker Hub
- Master image lifecycle management and security scanning
- Build automated deployment pipelines
- Understand enterprise registry patterns

---

## Exercise 1: Docker Hub Mastery

### 1.1 Repository Setup and Management

**Objective**: Create and manage repositories on Docker Hub with proper tagging strategies.

**Steps**:
1. Create a Docker Hub account if you don't have one
2. Create a new public repository named `my-enterprise-app`
3. Build a simple Node.js application with the following structure:

```bash
mkdir my-enterprise-app && cd my-enterprise-app
```

Create `package.json`:
```json
{
  "name": "my-enterprise-app",
  "version": "1.0.0",
  "description": "Enterprise Docker Hub Demo",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "test": "echo \"No tests yet\" && exit 0"
  },
  "dependencies": {
    "express": "^4.18.0"
  }
}
```

Create `server.js`:
```javascript
const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.json({
    message: 'Enterprise Docker App',
    version: process.env.APP_VERSION || '1.0.0',
    environment: process.env.NODE_ENV || 'development',
    timestamp: new Date().toISOString()
  });
});

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy' });
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
```

Create optimized `Dockerfile`:
```dockerfile
# Multi-stage build for production
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:18-alpine AS production
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY . .
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001
USER nodejs
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })"
CMD ["npm", "start"]
```

4. Build and tag your image:
```bash
docker build -t your-dockerhub-username/my-enterprise-app:1.0.0 .
docker tag your-dockerhub-username/my-enterprise-app:1.0.0 your-dockerhub-username/my-enterprise-app:latest
```

5. Push to Docker Hub:
```bash
docker login
docker push your-dockerhub-username/my-enterprise-app:1.0.0
docker push your-dockerhub-username/my-enterprise-app:latest
```

**Validation**:
- Verify your image appears on Docker Hub
- Pull and run the image on a different machine
- Check image layers and size optimization

### 1.2 Automated Builds with GitHub Integration

**Objective**: Set up automated builds using GitHub integration.

**Steps**:
1. Create a GitHub repository for your application
2. Push your code to GitHub
3. In Docker Hub, go to your repository settings
4. Connect to GitHub and enable automated builds
5. Configure build rules:
   - Build on `main` branch pushes → `latest` tag
   - Build on version tags (`v*`) → corresponding version tags
   - Build on `develop` branch → `dev` tag

6. Create a webhook test:
   - Modify your application
   - Push changes to GitHub
   - Verify automatic build triggers

**Validation**:
- Confirm automatic builds trigger on code changes
- Verify different branches create appropriate tags
- Test webhook functionality

---

## Exercise 2: Private Registry Implementation

### 2.1 Local Registry with Authentication

**Objective**: Set up a secure private Docker registry with authentication.

**Steps**:
1. Create registry directory structure:
```bash
mkdir -p registry/{data,auth,certs}
cd registry
```

2. Generate certificates for HTTPS:
```bash
openssl req -newkey rsa:4096 -nodes -sha256 -keyout certs/domain.key \
  -x509 -days 365 -out certs/domain.crt \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"
```

3. Create htpasswd file for authentication:
```bash
docker run --rm -it \
  -v $(pwd)/auth:/auth \
  httpd:2.4-alpine htpasswd -Bbn admin secretpassword > auth/htpasswd
```

4. Create `docker-compose.yml` for registry:
```yaml
version: '3.8'

services:
  registry:
    image: registry:2.8
    container_name: private-registry
    restart: always
    ports:
      - "5000:5000"
    environment:
      REGISTRY_AUTH: htpasswd
      REGISTRY_AUTH_HTPASSWD_REALM: Registry Realm
      REGISTRY_AUTH_HTPASSWD_PATH: /auth/htpasswd
      REGISTRY_HTTP_TLS_CERTIFICATE: /certs/domain.crt
      REGISTRY_HTTP_TLS_KEY: /certs/domain.key
      REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY: /data
    volumes:
      - ./data:/data
      - ./auth:/auth
      - ./certs:/certs

  registry-ui:
    image: joxit/docker-registry-ui:latest
    container_name: registry-ui
    restart: always
    ports:
      - "8080:80"
    environment:
      REGISTRY_TITLE: "Private Docker Registry"
      REGISTRY_URL: https://localhost:5000
      SINGLE_REGISTRY: true
      NGINX_PROXY_PASS_URL: https://registry:5000
    depends_on:
      - registry
```

5. Start the registry:
```bash
docker-compose up -d
```

6. Configure Docker to trust your registry:
```bash
# Add to /etc/docker/daemon.json
{
  "insecure-registries": ["localhost:5000"]
}
sudo systemctl restart docker
```

7. Test authentication and image operations:
```bash
# Login to private registry
docker login localhost:5000
Username: admin
Password: secretpassword

# Tag and push an image
docker tag your-dockerhub-username/my-enterprise-app:latest localhost:5000/my-enterprise-app:1.0.0
docker push localhost:5000/my-enterprise-app:1.0.0

# Pull from private registry
docker pull localhost:5000/my-enterprise-app:1.0.0
```

**Validation**:
- Access registry UI at `http://localhost:8080`
- Verify authentication is required
- Confirm image storage and retrieval

### 2.2 Registry with Harbor

**Objective**: Deploy Harbor as an enterprise-grade registry solution.

**Steps**:
1. Download Harbor installer:
```bash
wget https://github.com/goharbor/harbor/releases/download/v2.7.0/harbor-offline-installer-v2.7.0.tgz
tar xvf harbor-offline-installer-v2.7.0.tgz
cd harbor
```

2. Configure Harbor (`harbor.yml`):
```yaml
hostname: harbor.local
http:
  port: 80
https:
  port: 443
  certificate: /path/to/cert
  private_key: /path/to/key

harbor_admin_password: Harbor12345

database:
  password: root123
  max_idle_conns: 50
  max_open_conns: 1000

data_volume: /data
log:
  level: info
  local:
    rotate_count: 50
    rotate_size: 200M
    location: /var/log/harbor
```

3. Install Harbor:
```bash
sudo ./install.sh --with-trivy --with-chartmuseum
```

4. Access Harbor at `https://harbor.local` (admin/Harbor12345)
5. Create a new project called "enterprise-apps"
6. Configure project settings:
   - Enable vulnerability scanning
   - Set up retention policies
   - Configure robot accounts

**Validation**:
- Access Harbor web interface
- Create projects and manage users
- Push and scan images for vulnerabilities

---

## Exercise 3: CI/CD Pipeline Implementation

### 3.1 GitHub Actions Pipeline

**Objective**: Create a complete CI/CD pipeline using GitHub Actions.

**Steps**:
1. Create `.github/workflows/docker-build.yml`:
```yaml
name: Docker Build and Deploy

on:
  push:
    branches: [ main, develop ]
    tags: [ 'v*' ]
  pull_request:
    branches: [ main ]

env:
  REGISTRY: docker.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'

      - name: Install dependencies
        run: npm ci

      - name: Run tests
        run: npm test

      - name: Run linting
        run: npm run lint || echo "No linting configured"

  security-scan:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          format: 'sarif'
          output: 'trivy-results.sarif'

      - name: Upload Trivy scan results
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-results.sarif'

  build:
    needs: [test, security-scan]
    runs-on: ubuntu-latest
    outputs:
      image-digest: ${{ steps.build.outputs.digest }}
      image-uri: ${{ steps.build.outputs.image-uri }}
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=ref,event=branch
            type=ref,event=pr
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=sha,prefix=sha-,format=short

      - name: Build and push Docker image
        id: build
        uses: docker/build-push-action@v5
        with:
          context: .
          platforms: linux/amd64,linux/arm64
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Generate SBOM
        uses: anchore/sbom-action@v0
        with:
          image: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ steps.meta.outputs.version }}
          format: spdx-json
          output-file: sbom.spdx.json

      - name: Upload SBOM
        uses: actions/upload-artifact@v3
        with:
          name: sbom
          path: sbom.spdx.json

  deploy-staging:
    needs: build
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/develop'
    environment: staging
    steps:
      - name: Deploy to staging
        run: |
          echo "Deploying ${{ needs.build.outputs.image-uri }} to staging"
          # Add your staging deployment logic here

  deploy-production:
    needs: build
    runs-on: ubuntu-latest
    if: startsWith(github.ref, 'refs/tags/v')
    environment: production
    steps:
      - name: Deploy to production
        run: |
          echo "Deploying ${{ needs.build.outputs.image-uri }} to production"
          # Add your production deployment logic here
```

2. Set up GitHub secrets:
   - `DOCKERHUB_USERNAME`: Your Docker Hub username
   - `DOCKERHUB_TOKEN`: Docker Hub access token

3. Create `.dockerignore`:
```
node_modules
npm-debug.log
Dockerfile
.dockerignore
.git
.gitignore
README.md
.env
.nyc_output
coverage
.nyc_output
.coverage
.cache
```

**Validation**:
- Push code changes and verify pipeline execution
- Check that images are built and pushed
- Verify security scanning results
- Confirm deployment to staging/production

### 3.2 GitLab CI/CD Pipeline

**Objective**: Implement CI/CD pipeline using GitLab CI.

**Steps**:
1. Create `.gitlab-ci.yml`:
```yaml
stages:
  - test
  - security
  - build
  - deploy

variables:
  DOCKER_DRIVER: overlay2
  DOCKER_TLS_CERTDIR: "/certs"
  IMAGE_TAG: $CI_REGISTRY_IMAGE:$CI_COMMIT_REF_SLUG
  LATEST_TAG: $CI_REGISTRY_IMAGE:latest

before_script:
  - docker info

test:
  stage: test
  image: node:18-alpine
  script:
    - npm ci
    - npm test
  coverage: '/Statements\s*:\s*(\d+\.\d+)%/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura-coverage.xml

security:
  stage: security
  image: docker:latest
  services:
    - docker:dind
  script:
    - docker build -t temp-image .
    - |
      docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
        -v $(pwd):/tmp/.cache/ aquasec/trivy:latest \
        image --exit-code 0 --no-progress --format template \
        --template "@contrib/gitlab.tpl" -o /tmp/.cache/gl-container-scanning-report.json \
        temp-image
  artifacts:
    reports:
      container_scanning: gl-container-scanning-report.json

build:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
    - docker build --pull -t $IMAGE_TAG .
    - docker tag $IMAGE_TAG $LATEST_TAG
    - docker push $IMAGE_TAG
    - docker push $LATEST_TAG
  only:
    - main
    - develop
    - tags

deploy_staging:
  stage: deploy
  image: alpine:latest
  script:
    - echo "Deploying to staging environment"
    - echo "Image: $IMAGE_TAG"
  environment:
    name: staging
    url: https://staging.example.com
  only:
    - develop

deploy_production:
  stage: deploy
  image: alpine:latest
  script:
    - echo "Deploying to production environment"
    - echo "Image: $IMAGE_TAG"
  environment:
    name: production
    url: https://example.com
  when: manual
  only:
    - tags
```

**Validation**:
- Verify pipeline execution on code commits
- Check GitLab Container Registry for images
- Review security scan results
- Test manual deployment triggers

---

## Exercise 4: Image Lifecycle Management

### 4.1 Semantic Versioning and Tagging Strategy

**Objective**: Implement proper versioning and tagging strategies.

**Steps**:
1. Create versioning script (`version.sh`):
```bash
#!/bin/bash

set -e

CURRENT_VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
VERSION_TYPE=${1:-patch}

# Remove 'v' prefix for calculation
CURRENT_VERSION=${CURRENT_VERSION#v}

# Split version into array
IFS='.' read -ra VERSION_PARTS <<< "$CURRENT_VERSION"
MAJOR=${VERSION_PARTS[0]}
MINOR=${VERSION_PARTS[1]}
PATCH=${VERSION_PARTS[2]}

# Increment version based on type
case $VERSION_TYPE in
  major)
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
    ;;
  minor)
    MINOR=$((MINOR + 1))
    PATCH=0
    ;;
  patch)
    PATCH=$((PATCH + 1))
    ;;
  *)
    echo "Invalid version type: $VERSION_TYPE"
    exit 1
    ;;
esac

NEW_VERSION="v${MAJOR}.${MINOR}.${PATCH}"

echo "Current version: v$CURRENT_VERSION"
echo "New version: $NEW_VERSION"

# Create git tag
git tag -a $NEW_VERSION -m "Release $NEW_VERSION"
echo "Created tag: $NEW_VERSION"

# Build and tag Docker image
docker build -t $DOCKER_REPO:$NEW_VERSION \
  -t $DOCKER_REPO:${MAJOR}.${MINOR} \
  -t $DOCKER_REPO:${MAJOR} \
  -t $DOCKER_REPO:latest .

echo "Built Docker images with tags:"
echo "  - $DOCKER_REPO:$NEW_VERSION"
echo "  - $DOCKER_REPO:${MAJOR}.${MINOR}"
echo "  - $DOCKER_REPO:${MAJOR}"
echo "  - $DOCKER_REPO:latest"
```

2. Create image cleanup script (`cleanup.sh`):
```bash
#!/bin/bash

# Remove old development images
docker image prune -f

# Remove images older than 30 days
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.CreatedAt}}" | \
  awk '$3 ~ /month/ || $3 ~ /year/ {print $1":"$2}' | \
  xargs -r docker rmi

# Keep only last 5 versions of each image
for repo in $(docker images --format "{{.Repository}}" | sort -u); do
  docker images $repo --format "{{.Tag}}" | \
    grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | \
    sort -V | head -n -5 | \
    while read tag; do
      docker rmi $repo:$tag 2>/dev/null || true
    done
done
```

**Validation**:
- Test version bumping script
- Verify proper tag creation
- Run cleanup script and verify old images are removed

### 4.2 Registry Retention Policies

**Objective**: Configure automated cleanup and retention policies.

**Steps**:
1. Create Harbor retention policy:
   - Login to Harbor
   - Go to Project → Repositories
   - Configure retention policy:
     - Keep last 10 versions
     - Remove untagged images after 7 days
     - Keep images matching `^v\d+\.\d+\.\d+$` pattern

2. Create Docker Hub webhook for cleanup:
```javascript
// webhook-cleanup.js
const https = require('https');

const DOCKER_HUB_TOKEN = process.env.DOCKER_HUB_TOKEN;
const REPOSITORY = process.env.REPOSITORY;

async function cleanupOldImages() {
  const tags = await getRepositoryTags();
  const oldTags = tags.filter(tag => {
    // Keep only last 10 versions
    return tag.last_updated < new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
  });

  for (const tag of oldTags) {
    await deleteTag(tag.name);
  }
}

async function getRepositoryTags() {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'hub.docker.com',
      path: `/v2/repositories/${REPOSITORY}/tags/`,
      headers: {
        'Authorization': `Bearer ${DOCKER_HUB_TOKEN}`
      }
    };

    https.get(options, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => resolve(JSON.parse(data).results));
    }).on('error', reject);
  });
}

cleanupOldImages().catch(console.error);
```

**Validation**:
- Configure retention policies
- Test automatic cleanup
- Monitor storage usage reduction

---

## Exercise 5: Security and Compliance

### 5.1 Image Vulnerability Scanning

**Objective**: Implement comprehensive vulnerability scanning.

**Steps**:
1. Create scanning script (`scan.sh`):
```bash
#!/bin/bash

IMAGE=$1
SEVERITY=${2:-HIGH,CRITICAL}
FORMAT=${3:-json}

if [ -z "$IMAGE" ]; then
  echo "Usage: $0 <image> [severity] [format]"
  exit 1
fi

echo "Scanning image: $IMAGE"
echo "Severity filter: $SEVERITY"

# Run Trivy scan
trivy image \
  --severity $SEVERITY \
  --format $FORMAT \
  --output scan-results.$FORMAT \
  $IMAGE

# Check exit code
if [ $? -eq 0 ]; then
  echo "Scan completed successfully"
  if [ "$FORMAT" = "json" ]; then
    # Parse results
    HIGH_COUNT=$(jq '.Results[]?.Vulnerabilities[]? | select(.Severity=="HIGH") | .VulnerabilityID' scan-results.json | wc -l)
    CRITICAL_COUNT=$(jq '.Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL") | .VulnerabilityID' scan-results.json | wc -l)
    
    echo "Found $CRITICAL_COUNT critical and $HIGH_COUNT high severity vulnerabilities"
    
    if [ $CRITICAL_COUNT -gt 0 ]; then
      echo "❌ Critical vulnerabilities found - deployment blocked"
      exit 1
    elif [ $HIGH_COUNT -gt 5 ]; then
      echo "⚠️  Too many high severity vulnerabilities - review required"
      exit 1
    else
      echo "✅ Security scan passed"
    fi
  fi
else
  echo "Scan failed"
  exit 1
fi
```

2. Integrate with CI/CD pipeline (add to GitHub Actions):
```yaml
- name: Security scan
  run: |
    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
      -v $(pwd):/tmp aquasec/trivy:latest \
      image --severity HIGH,CRITICAL \
      --exit-code 1 \
      ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
```

**Validation**:
- Run scans on various images
- Test CI/CD integration
- Verify vulnerability reporting

### 5.2 Secrets Management and Compliance

**Objective**: Implement secure secrets handling and compliance checking.

**Steps**:
1. Create secret detection script:
```bash
#!/bin/bash

# Scan for secrets in image layers
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  trufflesecurity/trufflehog:latest \
  docker --image $1

# Check for compliance violations
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest \
  config /path/to/Dockerfile
```

2. Create compliance check:
```yaml
# compliance-check.yml
version: '1.0'
checks:
  - rule: "no-root-user"
    description: "Container should not run as root"
    severity: "HIGH"
    
  - rule: "no-secrets-in-env"
    description: "No secrets in environment variables"
    severity: "CRITICAL"
    
  - rule: "health-check-exists"
    description: "Container should have health check"
    severity: "MEDIUM"
```

**Validation**:
- Test secret detection on sample images
- Verify compliance checking
- Integration with pipeline gates

---

## 🎯 Final Project: Complete Enterprise Registry Solution

### Project Overview
Create a complete enterprise registry solution with:
- Private Harbor registry
- Automated CI/CD pipeline
- Security scanning and compliance
- Image lifecycle management
- Monitoring and alerting

### Requirements
1. **Registry Setup**:
   - Deploy Harbor with HTTPS
   - Configure LDAP/AD integration
   - Set up project-based access control
   - Enable vulnerability scanning

2. **CI/CD Integration**:
   - Multi-stage pipeline (test, build, scan, deploy)
   - Automated vulnerability assessment
   - Deployment gates based on security scores
   - Multi-environment promotion (dev → staging → prod)

3. **Security & Compliance**:
   - Image signing with Cosign
   - SBOM generation
   - Compliance policy enforcement
   - Secret scanning

4. **Monitoring & Operations**:
   - Registry health monitoring
   - Storage usage tracking
   - Audit logging
   - Automated cleanup

### Deliverables
1. Complete infrastructure code (Terraform/Ansible)
2. CI/CD pipeline definitions
3. Security policies and scanning configurations
4. Monitoring and alerting setup
5. Documentation and runbooks

### Success Criteria
- Zero-downtime registry deployment
- Automated vulnerability scanning with <24h detection
- 99.9% registry uptime
- Compliance with security policies
- Automated image lifecycle management

---

## 📚 Additional Resources

- [Docker Hub Official Documentation](https://docs.docker.com/docker-hub/)
- [Harbor Documentation](https://goharbor.io/docs/)
- [Trivy Security Scanner](https://aquasecurity.github.io/trivy/)
- [GitHub Actions Docker Guide](https://docs.github.com/en/actions/publishing-packages/publishing-docker-images)
- [GitLab Container Registry](https://docs.gitlab.com/ee/user/packages/container_registry/)

Remember: Enterprise registry management is about balancing security, reliability, and developer productivity! 🚀