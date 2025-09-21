#!/bin/bash
# Module 7: Container Registries & CI/CD - Comprehensive Demo Script

set -euo pipefail

# Demo Configuration
DEMO_PROJECT="webapp-demo"
DEMO_IMAGE="demo-api"
LOCAL_REGISTRY="localhost:5000"
HARBOR_REGISTRY="harbor.demo.local"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

highlight() {
    echo -e "${CYAN}🔹 $1${NC}"
}

section() {
    echo ""
    echo -e "${MAGENTA}========================================${NC}"
    echo -e "${MAGENTA} $1${NC}"
    echo -e "${MAGENTA}========================================${NC}"
    echo ""
}

# Wait for user input
wait_for_user() {
    read -p "Press Enter to continue or Ctrl+C to exit..."
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    local required_commands=("docker" "docker-compose" "jq" "curl")
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        error "Missing required commands: ${missing_commands[*]}"
        error "Please install the missing commands and try again"
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        error "Docker daemon is not running. Please start Docker and try again."
        exit 1
    fi
    
    success "All prerequisites met"
}

# Create demo application
create_demo_application() {
    section "Creating Demo Application"
    
    log "Creating demo Node.js application..."
    
    # Create project directory
    mkdir -p "$DEMO_PROJECT"
    cd "$DEMO_PROJECT"
    
    # Create package.json
    cat > package.json << 'EOF'
{
  "name": "webapp-demo",
  "version": "1.0.0",
  "description": "Demo application for Container Registry & CI/CD",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "test": "jest",
    "lint": "eslint .",
    "security": "npm audit"
  },
  "dependencies": {
    "express": "^4.18.2",
    "prom-client": "^14.2.0"
  },
  "devDependencies": {
    "jest": "^29.5.0",
    "eslint": "^8.40.0"
  },
  "engines": {
    "node": ">=18.0.0"
  }
}
EOF
    
    # Create main application
    cat > server.js << 'EOF'
const express = require('express');
const prometheus = require('prom-client');

const app = express();
const PORT = process.env.PORT || 3000;

// Prometheus metrics
const httpRequestsTotal = new prometheus.Counter({
    name: 'http_requests_total',
    help: 'Total number of HTTP requests',
    labelNames: ['method', 'status_code', 'endpoint']
});

const httpRequestDuration = new prometheus.Histogram({
    name: 'http_request_duration_seconds',
    help: 'Duration of HTTP requests in seconds',
    labelNames: ['method', 'endpoint']
});

// Middleware for metrics
app.use((req, res, next) => {
    const start = Date.now();
    
    res.on('finish', () => {
        const duration = (Date.now() - start) / 1000;
        const endpoint = req.route ? req.route.path : req.path;
        
        httpRequestsTotal
            .labels(req.method, res.statusCode, endpoint)
            .inc();
            
        httpRequestDuration
            .labels(req.method, endpoint)
            .observe(duration);
    });
    
    next();
});

app.use(express.json());

// Health endpoints
app.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        version: process.env.APP_VERSION || '1.0.0',
        environment: process.env.NODE_ENV || 'development',
        uptime: process.uptime()
    });
});

app.get('/ready', (req, res) => {
    res.json({
        status: 'ready',
        timestamp: new Date().toISOString()
    });
});

// Main routes
app.get('/', (req, res) => {
    res.json({
        message: 'Container Registry & CI/CD Demo API',
        version: process.env.APP_VERSION || '1.0.0',
        build: process.env.BUILD_NUMBER || 'unknown',
        commit: process.env.GIT_COMMIT || 'unknown',
        timestamp: new Date().toISOString()
    });
});

app.get('/api/info', (req, res) => {
    res.json({
        application: 'webapp-demo',
        version: process.env.APP_VERSION || '1.0.0',
        build_info: {
            number: process.env.BUILD_NUMBER || 'unknown',
            date: process.env.BUILD_DATE || 'unknown',
            commit: process.env.GIT_COMMIT || 'unknown',
            branch: process.env.GIT_BRANCH || 'unknown'
        },
        runtime: {
            node_version: process.version,
            platform: process.platform,
            architecture: process.arch,
            memory_usage: process.memoryUsage(),
            uptime: process.uptime()
        }
    });
});

// Metrics endpoint
app.get('/metrics', async (req, res) => {
    res.set('Content-Type', prometheus.register.contentType);
    res.end(await prometheus.register.metrics());
});

// Error handling
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).json({
        error: 'Internal Server Error',
        timestamp: new Date().toISOString()
    });
});

// 404 handler
app.use((req, res) => {
    res.status(404).json({
        error: 'Not Found',
        path: req.path,
        timestamp: new Date().toISOString()
    });
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('SIGTERM received, shutting down gracefully');
    process.exit(0);
});

process.on('SIGINT', () => {
    console.log('SIGINT received, shutting down gracefully');
    process.exit(0);
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`Server running on port ${PORT}`);
    console.log(`Version: ${process.env.APP_VERSION || '1.0.0'}`);
    console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
});
EOF
    
    # Create Dockerfile
    cat > Dockerfile << 'EOF'
# Multi-stage build for optimized image
FROM node:18-alpine AS builder

# Build arguments
ARG BUILD_DATE
ARG BUILD_NUMBER
ARG VCS_REF
ARG VCS_URL
ARG VERSION

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production && npm cache clean --force

# Production stage
FROM node:18-alpine AS production

# Install security updates
RUN apk update && apk upgrade && apk add --no-cache dumb-init

# Create non-root user
RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001

# Set working directory
WORKDIR /app

# Copy application files
COPY --from=builder /app/node_modules ./node_modules
COPY --chown=nodejs:nodejs . .

# Set build arguments as environment variables
ENV BUILD_DATE=$BUILD_DATE
ENV BUILD_NUMBER=$BUILD_NUMBER
ENV VCS_REF=$VCS_REF
ENV VCS_URL=$VCS_URL
ENV VERSION=$VERSION

# Add labels for metadata
LABEL org.opencontainers.image.created=$BUILD_DATE \
      org.opencontainers.image.version=$VERSION \
      org.opencontainers.image.revision=$VCS_REF \
      org.opencontainers.image.source=$VCS_URL \
      org.opencontainers.image.title="webapp-demo" \
      org.opencontainers.image.description="Demo application for Container Registry & CI/CD" \
      org.opencontainers.image.vendor="Demo Company" \
      maintainer="devops@demo.com"

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) }).on('error', () => process.exit(1))"

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]

# Start application
CMD ["npm", "start"]
EOF
    
    # Create .dockerignore
    cat > .dockerignore << 'EOF'
node_modules
npm-debug.log
.git
.gitignore
README.md
.env
coverage
.nyc_output
.DS_Store
*.log
.vscode
.idea
EOF
    
    # Create basic tests
    mkdir -p tests
    cat > tests/app.test.js << 'EOF'
const request = require('supertest');
const app = require('../server');

describe('Demo API', () => {
    test('GET / should return application info', async () => {
        const response = await request(app).get('/');
        expect(response.status).toBe(200);
        expect(response.body.message).toContain('Demo API');
    });

    test('GET /health should return health status', async () => {
        const response = await request(app).get('/health');
        expect(response.status).toBe(200);
        expect(response.body.status).toBe('healthy');
    });

    test('GET /ready should return readiness status', async () => {
        const response = await request(app).get('/ready');
        expect(response.status).toBe(200);
        expect(response.body.status).toBe('ready');
    });
});
EOF
    
    success "Demo application created successfully"
    cd ..
}

# Setup local registry
setup_local_registry() {
    section "Setting Up Local Docker Registry"
    
    log "Creating local Docker registry..."
    
    # Create registry directory structure
    mkdir -p registry-data/{data,auth,certs,config}
    
    # Create registry configuration
    cat > registry-data/config/config.yml << 'EOF'
version: 0.1
log:
  fields:
    service: registry
storage:
  cache:
    blobdescriptor: inmemory
  filesystem:
    rootdirectory: /var/lib/registry
  delete:
    enabled: true
  maintenance:
    uploadpurging:
      enabled: true
      age: 168h
      interval: 24h
      dryrun: false
http:
  addr: :5000
  headers:
    X-Content-Type-Options: [nosniff]
    Access-Control-Allow-Origin: ['*']
    Access-Control-Allow-Methods: ['HEAD', 'GET', 'OPTIONS', 'DELETE']
    Access-Control-Allow-Headers: ['Authorization', 'Accept', 'Cache-Control']
    Access-Control-Max-Age: [1728000]
    Access-Control-Allow-Credentials: [true]
    Access-Control-Expose-Headers: ['Docker-Content-Digest']
health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3
EOF
    
    # Create basic auth (optional)
    mkdir -p registry-data/auth
    # docker run --entrypoint htpasswd httpd:2 -Bbn admin password > registry-data/auth/htpasswd
    
    # Create registry docker-compose file
    cat > docker-compose.registry.yml << 'EOF'
version: '3.8'

services:
  registry:
    image: registry:2.8
    container_name: local-registry
    restart: unless-stopped
    ports:
      - "5000:5000"
    environment:
      REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY: /var/lib/registry
      REGISTRY_STORAGE_DELETE_ENABLED: "true"
    volumes:
      - ./registry-data/data:/var/lib/registry
      - ./registry-data/config/config.yml:/etc/docker/registry/config.yml:ro
    networks:
      - registry-network
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:5000/v2/"]
      interval: 30s
      timeout: 10s
      retries: 3

  registry-ui:
    image: joxit/docker-registry-ui:2.5.0
    container_name: registry-ui
    restart: unless-stopped
    ports:
      - "8080:80"
    environment:
      SINGLE_REGISTRY: "true"
      REGISTRY_TITLE: "Local Docker Registry"
      DELETE_IMAGES: "true"
      SHOW_CONTENT_DIGEST: "true"
      NGINX_PROXY_PASS_URL: "http://registry:5000"
      SHOW_CATALOG_NB_TAGS: "true"
      CATALOG_MIN_BRANCHES: 1
      CATALOG_MAX_BRANCHES: 1
      TAGLIST_PAGE_SIZE: 100
      CATALOG_ELEMENTS_LIMIT: 1000
    depends_on:
      - registry
    networks:
      - registry-network

networks:
  registry-network:
    driver: bridge
EOF
    
    # Start local registry
    log "Starting local Docker registry..."
    docker-compose -f docker-compose.registry.yml up -d
    
    # Wait for registry to be ready
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -s "http://localhost:5000/v2/" >/dev/null 2>&1; then
            success "Local registry is ready"
            break
        fi
        
        log "Waiting for registry to be ready... (attempt $attempt/$max_attempts)"
        sleep 2
        ((attempt++))
    done
    
    if [[ $attempt -gt $max_attempts ]]; then
        error "Registry failed to start within timeout"
        return 1
    fi
    
    highlight "Registry UI available at: http://localhost:8080"
    success "Local registry setup completed"
}

# Docker Hub operations demo
demo_docker_hub_operations() {
    section "Docker Hub Operations Demo"
    
    log "Demonstrating Docker Hub operations..."
    
    # Note: This demo requires Docker Hub login
    warning "Note: Docker Hub operations require authentication"
    warning "This demo will show the commands without actually pushing to Docker Hub"
    
    highlight "Building image for Docker Hub..."
    cd "$DEMO_PROJECT"
    
    # Build image with proper tags
    docker build \
        --build-arg BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --build-arg BUILD_NUMBER="1001" \
        --build-arg VCS_REF="abc123def" \
        --build-arg VERSION="1.0.0" \
        -t "demo-user/$DEMO_IMAGE:1.0.0" \
        -t "demo-user/$DEMO_IMAGE:latest" \
        .
    
    success "Image built with Docker Hub tags"
    
    highlight "Commands for Docker Hub operations:"
    echo "# Login to Docker Hub"
    echo "docker login"
    echo ""
    echo "# Push specific version"
    echo "docker push demo-user/$DEMO_IMAGE:1.0.0"
    echo ""
    echo "# Push latest tag"
    echo "docker push demo-user/$DEMO_IMAGE:latest"
    echo ""
    echo "# View image on Docker Hub"
    echo "# Visit: https://hub.docker.com/r/demo-user/$DEMO_IMAGE"
    
    cd ..
    
    success "Docker Hub operations demo completed"
}

# Local registry operations demo
demo_local_registry_operations() {
    section "Local Registry Operations Demo"
    
    log "Demonstrating local registry operations..."
    
    cd "$DEMO_PROJECT"
    
    # Tag image for local registry
    highlight "Tagging image for local registry..."
    docker tag "demo-user/$DEMO_IMAGE:1.0.0" "$LOCAL_REGISTRY/$DEMO_IMAGE:1.0.0"
    docker tag "demo-user/$DEMO_IMAGE:1.0.0" "$LOCAL_REGISTRY/$DEMO_IMAGE:latest"
    docker tag "demo-user/$DEMO_IMAGE:1.0.0" "$LOCAL_REGISTRY/$DEMO_IMAGE:build-1001"
    
    # Push to local registry
    highlight "Pushing image to local registry..."
    docker push "$LOCAL_REGISTRY/$DEMO_IMAGE:1.0.0"
    docker push "$LOCAL_REGISTRY/$DEMO_IMAGE:latest"
    docker push "$LOCAL_REGISTRY/$DEMO_IMAGE:build-1001"
    
    success "Images pushed to local registry"
    
    # List images in registry
    highlight "Listing images in local registry..."
    echo "Registry catalog:"
    curl -s "http://localhost:5000/v2/_catalog" | jq .
    
    echo ""
    echo "Tags for $DEMO_IMAGE:"
    curl -s "http://localhost:5000/v2/$DEMO_IMAGE/tags/list" | jq .
    
    # Pull image from local registry
    highlight "Pulling image from local registry..."
    docker rmi "$LOCAL_REGISTRY/$DEMO_IMAGE:1.0.0" || true
    docker pull "$LOCAL_REGISTRY/$DEMO_IMAGE:1.0.0"
    
    success "Image pulled from local registry"
    
    cd ..
}

# Image lifecycle management demo
demo_image_lifecycle() {
    section "Image Lifecycle Management Demo"
    
    log "Demonstrating image lifecycle management..."
    
    cd "$DEMO_PROJECT"
    
    # Create lifecycle management script
    cat > image-lifecycle.sh << 'EOF'
#!/bin/bash
set -euo pipefail

REGISTRY_URL="localhost:5000"
IMAGE_NAME="demo-api"
VERSIONS=("1.0.0" "1.1.0" "1.2.0" "2.0.0")

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Build and tag multiple versions
for version in "${VERSIONS[@]}"; do
    log "Building version $version..."
    
    docker build \
        --build-arg VERSION="$version" \
        --build-arg BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --build-arg BUILD_NUMBER="$(date +%s)" \
        -t "$REGISTRY_URL/$IMAGE_NAME:$version" \
        .
    
    # Tag with semantic versioning
    if [[ "$version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
        major="${BASH_REMATCH[1]}"
        minor="${BASH_REMATCH[2]}"
        
        docker tag "$REGISTRY_URL/$IMAGE_NAME:$version" "$REGISTRY_URL/$IMAGE_NAME:$major"
        docker tag "$REGISTRY_URL/$IMAGE_NAME:$version" "$REGISTRY_URL/$IMAGE_NAME:$major.$minor"
    fi
    
    # Push all tags
    docker push "$REGISTRY_URL/$IMAGE_NAME:$version"
    [[ "$version" =~ ^([0-9]+) ]] && docker push "$REGISTRY_URL/$IMAGE_NAME:${BASH_REMATCH[1]}" || true
    [[ "$version" =~ ^([0-9]+)\.([0-9]+) ]] && docker push "$REGISTRY_URL/$IMAGE_NAME:${BASH_REMATCH[1]}.${BASH_REMATCH[2]}" || true
    
    log "Version $version built and pushed"
done

log "All versions processed"

# List all tags
echo ""
echo "All tags in registry:"
curl -s "http://localhost:5000/v2/$IMAGE_NAME/tags/list" | jq -r '.tags[]' | sort -V
EOF
    
    chmod +x image-lifecycle.sh
    
    highlight "Running image lifecycle demo..."
    ./image-lifecycle.sh
    
    success "Image lifecycle management demo completed"
    cd ..
}

# Security scanning demo
demo_security_scanning() {
    section "Security Scanning Demo"
    
    log "Demonstrating security scanning..."
    
    # Create security scanning script
    cat > security-scan-demo.sh << 'EOF'
#!/bin/bash
set -euo pipefail

IMAGE_TAG="localhost:5000/demo-api:1.0.0"
SCAN_DIR="./security-reports"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

mkdir -p "$SCAN_DIR"

# Simulate Trivy scan (since Trivy might not be installed)
log "Simulating Trivy vulnerability scan..."

cat > "$SCAN_DIR/trivy-vulnerabilities.json" << 'EOT'
{
  "SchemaVersion": 2,
  "ArtifactName": "localhost:5000/demo-api:1.0.0",
  "ArtifactType": "container_image",
  "Results": [
    {
      "Target": "node_modules",
      "Class": "lang-pkgs",
      "Type": "npm",
      "Vulnerabilities": [
        {
          "VulnerabilityID": "CVE-2023-26136",
          "PkgName": "tough-cookie",
          "PkgVersion": "4.0.0",
          "Severity": "MEDIUM",
          "Title": "tough-cookie: prototype pollution in cookie memstore",
          "Description": "Versions of the package tough-cookie before 4.1.3 are vulnerable to Prototype Pollution..."
        },
        {
          "VulnerabilityID": "CVE-2022-25883",
          "PkgName": "semver",
          "PkgVersion": "5.7.1",
          "Severity": "HIGH",
          "Title": "semver: Regular expression denial of service",
          "Description": "The package semver before 7.5.2 are vulnerable to Regular Expression Denial of Service..."
        }
      ]
    }
  ]
}
EOT

# Parse and display results
CRITICAL=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "CRITICAL")] | length' "$SCAN_DIR/trivy-vulnerabilities.json")
HIGH=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "HIGH")] | length' "$SCAN_DIR/trivy-vulnerabilities.json")
MEDIUM=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "MEDIUM")] | length' "$SCAN_DIR/trivy-vulnerabilities.json")
LOW=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "LOW")] | length' "$SCAN_DIR/trivy-vulnerabilities.json")

log "Vulnerability scan results:"
log "  Critical: $CRITICAL"
log "  High: $HIGH"
log "  Medium: $MEDIUM"
log "  Low: $LOW"

# Generate security report
cat > "$SCAN_DIR/security-report.md" << EOT
# Security Scan Report

## Image Information
- **Image**: $IMAGE_TAG
- **Scan Date**: $(date -u +%Y-%m-%dT%H:%M:%SZ)

## Vulnerability Summary
- **Critical**: $CRITICAL
- **High**: $HIGH
- **Medium**: $MEDIUM
- **Low**: $LOW

## Recommendations
1. Update dependencies to latest secure versions
2. Use minimal base images
3. Implement regular security scanning in CI/CD
4. Monitor for new vulnerabilities
EOT

log "Security scan completed. Report saved to $SCAN_DIR/security-report.md"
EOF
    
    chmod +x security-scan-demo.sh
    ./security-scan-demo.sh
    
    success "Security scanning demo completed"
}

# CI/CD pipeline simulation
demo_cicd_pipeline() {
    section "CI/CD Pipeline Simulation"
    
    log "Simulating CI/CD pipeline..."
    
    # Create pipeline simulation script
    cat > cicd-pipeline-demo.sh << 'EOF'
#!/bin/bash
set -euo pipefail

REGISTRY_URL="localhost:5000"
IMAGE_NAME="demo-api"
VERSION="2.0.0"
BUILD_NUMBER="$(date +%s)"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

success() {
    echo "✅ $1"
}

# Stage 1: Build
log "🔨 Stage 1: Build"
log "Building application image..."

docker build \
    --build-arg BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --build-arg BUILD_NUMBER="$BUILD_NUMBER" \
    --build-arg VCS_REF="$(echo $RANDOM | md5sum | head -c 8)" \
    --build-arg VERSION="$VERSION" \
    -t "$REGISTRY_URL/$IMAGE_NAME:$VERSION" \
    -t "$REGISTRY_URL/$IMAGE_NAME:build-$BUILD_NUMBER" \
    webapp-demo/

success "Build completed"

# Stage 2: Test
log "🧪 Stage 2: Test"
log "Running container tests..."

# Simulate tests
docker run --rm "$REGISTRY_URL/$IMAGE_NAME:$VERSION" sh -c "echo 'Running unit tests...' && sleep 2 && echo 'All tests passed'"

success "Tests completed"

# Stage 3: Security Scan
log "🔒 Stage 3: Security Scan"
log "Running security scan..."

# Simulate security scan
echo "Scanning for vulnerabilities..."
sleep 2
echo "✅ No critical vulnerabilities found"

success "Security scan completed"

# Stage 4: Push to Registry
log "📦 Stage 4: Push to Registry"
log "Pushing image to registry..."

docker push "$REGISTRY_URL/$IMAGE_NAME:$VERSION"
docker push "$REGISTRY_URL/$IMAGE_NAME:build-$BUILD_NUMBER"

success "Images pushed to registry"

# Stage 5: Deploy (Simulation)
log "🚀 Stage 5: Deploy"
log "Deploying to staging environment..."

echo "Updating Kubernetes deployment..."
echo "kubectl set image deployment/demo-api api=$REGISTRY_URL/$IMAGE_NAME:$VERSION -n staging"

echo "Waiting for rollout to complete..."
sleep 3

success "Deployment completed"

log "🎉 Pipeline completed successfully!"
log "Image: $REGISTRY_URL/$IMAGE_NAME:$VERSION"
log "Build: $BUILD_NUMBER"
EOF
    
    chmod +x cicd-pipeline-demo.sh
    ./cicd-pipeline-demo.sh
    
    success "CI/CD pipeline simulation completed"
}

# Registry maintenance demo
demo_registry_maintenance() {
    section "Registry Maintenance Demo"
    
    log "Demonstrating registry maintenance..."
    
    # Create maintenance script
    cat > registry-maintenance.sh << 'EOF'
#!/bin/bash
set -euo pipefail

REGISTRY_URL="localhost:5000"
API_URL="http://localhost:5000/v2"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# List all repositories
log "Listing all repositories..."
curl -s "$API_URL/_catalog" | jq -r '.repositories[]' | while read repo; do
    echo "Repository: $repo"
    
    # List tags for each repository
    tags=$(curl -s "$API_URL/$repo/tags/list" | jq -r '.tags[]?' 2>/dev/null || echo "")
    if [[ -n "$tags" ]]; then
        echo "  Tags:"
        echo "$tags" | while read tag; do
            echo "    - $tag"
        done
    else
        echo "  No tags found"
    fi
    echo ""
done

# Simulate cleanup of old images
log "Simulating cleanup of old images..."
echo "Would remove images older than 30 days..."
echo "Would keep latest 5 versions of each image..."

log "Registry maintenance simulation completed"
EOF
    
    chmod +x registry-maintenance.sh
    ./registry-maintenance.sh
    
    success "Registry maintenance demo completed"
}

# Cleanup demo environment
cleanup_demo() {
    section "Cleanup Demo Environment"
    
    log "Cleaning up demo environment..."
    
    # Stop and remove containers
    docker-compose -f docker-compose.registry.yml down -v 2>/dev/null || true
    
    # Remove demo images
    docker rmi $(docker images "localhost:5000/demo-api" -q) 2>/dev/null || true
    docker rmi $(docker images "demo-user/demo-api" -q) 2>/dev/null || true
    
    # Remove demo files
    rm -rf registry-data webapp-demo
    rm -f docker-compose.registry.yml
    rm -f *-demo.sh
    rm -rf security-reports
    
    success "Cleanup completed"
}

# Main demo execution
main() {
    echo "=================================================="
    echo "Module 7: Container Registries & CI/CD Demo"
    echo "=================================================="
    echo ""
    echo "This demo will showcase:"
    echo "1. Setting up local Docker registry"
    echo "2. Docker Hub operations"
    echo "3. Image lifecycle management"
    echo "4. Security scanning"
    echo "5. CI/CD pipeline simulation"
    echo "6. Registry maintenance"
    echo ""
    
    wait_for_user
    
    # Check prerequisites
    check_prerequisites
    
    # Create demo application
    create_demo_application
    wait_for_user
    
    # Setup local registry
    setup_local_registry
    wait_for_user
    
    # Docker Hub operations demo
    demo_docker_hub_operations
    wait_for_user
    
    # Local registry operations demo
    demo_local_registry_operations
    wait_for_user
    
    # Image lifecycle management demo
    demo_image_lifecycle
    wait_for_user
    
    # Security scanning demo
    demo_security_scanning
    wait_for_user
    
    # CI/CD pipeline simulation
    demo_cicd_pipeline
    wait_for_user
    
    # Registry maintenance demo
    demo_registry_maintenance
    wait_for_user
    
    # Show final results
    section "Demo Summary"
    log "Registry UI: http://localhost:8080"
    log "API endpoint: http://localhost:5000/v2"
    
    echo ""
    echo "Images in local registry:"
    curl -s "http://localhost:5000/v2/_catalog" | jq .
    
    echo ""
    read -p "Would you like to cleanup the demo environment? (y/N): " cleanup_choice
    if [[ "$cleanup_choice" =~ ^[Yy]$ ]]; then
        cleanup_demo
    else
        log "Demo environment preserved. Run docker-compose -f docker-compose.registry.yml down to stop registry."
    fi
    
    success "Module 7 demo completed successfully!"
}

# Handle script interruption
trap 'echo ""; warning "Demo interrupted. Run with cleanup option to clean up."; exit 1' INT TERM

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-demo}" in
        "demo")
            main
            ;;
        "cleanup")
            cleanup_demo
            ;;
        *)
            echo "Usage: $0 [demo|cleanup]"
            echo "  demo    - Run complete demo (default)"
            echo "  cleanup - Clean up demo environment"
            exit 1
            ;;
    esac
fi