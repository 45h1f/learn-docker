# Module 2: Docker Images & Dockerfile Best Practices - Exercises

## 🎯 Exercise 1: Basic Dockerfile Optimization

### Task: Optimize a Python Web Application
Create different versions of a Dockerfile and compare their efficiency.

**Setup:**
```bash
cd /home/ashif/Projects/personal/Docker/lean_docker/02-images-best-practices
```

**Part A: Build and Compare Images**
```bash
# Build the bad example (if Docker is available)
docker build -f Dockerfile.bad -t myapp:bad .

# Build the good example
docker build -f Dockerfile.good -t myapp:good .

# Build the excellent example
docker build -f Dockerfile -t myapp:excellent .

# Compare sizes
docker images | grep myapp
```

**Part B: Analyze the Differences**
1. Compare image sizes
2. Count the number of layers: `docker history myapp:excellent`
3. Check security: `docker run --rm myapp:excellent whoami`

**Expected Results:**
- Bad: ~800MB-1GB (Ubuntu base)
- Good: ~150-200MB (Python slim base)
- Excellent: ~50-80MB (Alpine + multi-stage)

---

## 🎯 Exercise 2: Multi-Stage Build Practice

### Task: Create a Multi-Stage Node.js Application

**Step 1: Create a Simple Node.js App**
```bash
mkdir -p nodejs-app && cd nodejs-app

# Create package.json
cat > package.json << 'EOF'
{
  "name": "docker-node-app",
  "version": "1.0.0",
  "description": "Node.js app for Docker optimization",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "lodash": "^4.17.21"
  }
}
EOF

# Create server.js
cat > server.js << 'EOF'
const express = require('express');
const _ = require('lodash');

const app = express();
const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => {
    const data = {
        message: 'Hello from Docker!',
        timestamp: new Date().toISOString(),
        environment: process.env.NODE_ENV || 'development',
        version: process.env.npm_package_version || '1.0.0',
        features: _.shuffle(['fast', 'secure', 'optimized', 'minimal'])
    };
    res.json(data);
});

app.get('/health', (req, res) => {
    res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`Server running on port ${PORT}`);
});
EOF
```

**Step 2: Create Multi-Stage Dockerfile**
```dockerfile
# Build stage
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Production stage
FROM node:18-alpine AS production
RUN addgroup -g 1001 -S nodejs && \
    adduser -S -u 1001 -h /app -s /sbin/nologin nodejs

WORKDIR /app
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --chown=nodejs:nodejs . .

USER nodejs
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/health', (res) => process.exit(res.statusCode === 200 ? 0 : 1))"

CMD ["node", "server.js"]
```

**Step 3: Test and Compare**
```bash
# Build and run
docker build -t nodeapp:optimized .
docker run -d --name nodeapp -p 3000:3000 nodeapp:optimized

# Test
curl http://localhost:3000
curl http://localhost:3000/health

# Check image size
docker images nodeapp:optimized
```

---

## 🎯 Exercise 3: Security Hardening

### Task: Implement Security Best Practices

**Create a security-focused Dockerfile for a Python app:**

```dockerfile
# Use specific version (not latest)
FROM python:3.9.18-slim-bullseye

# Update packages and install security updates
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        curl \
        ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create non-root user with specific UID/GID
RUN groupadd -r -g 1000 appuser && \
    useradd -r -u 1000 -g appuser -d /app -s /sbin/nologin appuser

# Set working directory
WORKDIR /app

# Copy requirements first for layer caching
COPY requirements.txt .

# Install Python packages without cache
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY --chown=appuser:appuser app.py .

# Remove unnecessary packages and files
RUN apt-get purge -y --auto-remove && \
    rm -rf /tmp/* /var/tmp/* ~/.cache

# Switch to non-root user
USER appuser

# Set security-focused environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app

# Use non-privileged port
EXPOSE 8080

# Add health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Use secure startup
CMD ["python", "-c", "import app; app.app.run(host='0.0.0.0', port=8080)"]
```

**Security Checklist:**
- [ ] Non-root user
- [ ] Specific image versions
- [ ] Minimal packages
- [ ] Package cache cleanup
- [ ] Security updates applied
- [ ] Non-privileged ports
- [ ] Read-only filesystem where possible

---

## 🎯 Exercise 4: Layer Optimization Challenge

### Task: Minimize Layers and Optimize Caching

**Bad Example (many layers):**
```dockerfile
FROM ubuntu:20.04
RUN apt-get update
RUN apt-get install -y python3
RUN apt-get install -y python3-pip
RUN apt-get install -y curl
RUN apt-get install -y git
COPY . /app
WORKDIR /app
RUN pip3 install flask
RUN pip3 install requests
RUN pip3 install psutil
CMD ["python3", "app.py"]
```

**Your Task: Optimize to Maximum 5 Layers**
Create an optimized version with:
1. Better base image choice
2. Combined RUN commands
3. Proper layer ordering for cache efficiency
4. Cleanup in the same layer
5. Non-root user

**Solution Template:**
```dockerfile
# Layer 1: Base image
FROM python:3.9-slim

# Layer 2: System setup + user creation + package installation
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    groupadd -r appuser && useradd -r -g appuser appuser

# Layer 3: Requirements (for better caching)
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Layer 4: Application code
COPY --chown=appuser:appuser . .
USER appuser

# Layer 5: Runtime configuration
EXPOSE 5000
CMD ["python", "app.py"]
```

---

## 🎯 Exercise 5: Build Performance Optimization

### Task: Optimize Build Speed

**Create .dockerignore file:**
```bash
# Version control
.git/
.gitignore

# IDE and editor files
.vscode/
.idea/
*.swp
*.swo

# OS generated files
.DS_Store
Thumbs.db

# Logs and temporary files
*.log
tmp/
temp/

# Documentation
README.md
docs/

# Test files
tests/
*_test.py
test_*.py

# Python cache
__pycache__/
*.pyc
.pytest_cache/

# Virtual environments
venv/
env/
.env

# Build artifacts
dist/
build/
*.egg-info/

# Large files not needed
*.tar.gz
*.zip
node_modules/
```

**Measure Build Performance:**
```bash
# Time the build
time docker build -t myapp:perf .

# Check build context size
du -sh .

# Build with BuildKit for better performance
DOCKER_BUILDKIT=1 docker build -t myapp:buildkit .
```

---

## 🎯 Exercise 6: Image Analysis and Scanning

### Task: Analyze and Secure Your Images

**Step 1: Use Docker Scout (if available)**
```bash
# Quick vulnerability scan
docker scout quickview myapp:latest

# Detailed CVE analysis
docker scout cves myapp:latest

# Get recommendations
docker scout recommendations myapp:latest
```

**Step 2: Manual Layer Analysis**
```bash
# Examine image layers
docker history myapp:latest

# Show layer sizes
docker history --no-trunc --format "table {{.CreatedBy}}\t{{.Size}}" myapp:latest

# Inspect image metadata
docker inspect myapp:latest | jq '.[0].Config'
```

**Step 3: Size Analysis**
```bash
# Compare image sizes
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep myapp

# Check specific layer content (requires dive tool)
# If dive is installed: dive myapp:latest
```

---

## 🧪 Challenge Exercise: Enterprise Production Image

### Task: Create a Production-Ready Enterprise Image

**Requirements:**
1. **Base**: Alpine Linux for minimal size
2. **Security**: Non-root user, minimal packages, vulnerability-free
3. **Performance**: Multi-stage build, optimized layers
4. **Observability**: Health checks, proper logging
5. **Size**: Under 100MB
6. **Functionality**: Python Flask app with database connectivity

**Template Structure:**
```dockerfile
# syntax=docker/dockerfile:1
ARG PYTHON_VERSION=3.9
ARG ALPINE_VERSION=3.17

# Build stage
FROM python:${PYTHON_VERSION}-alpine${ALPINE_VERSION} AS builder
# ... build logic ...

# Security scanning stage
FROM builder AS security-scan
# Add security scanning tools if needed

# Production stage
FROM python:${PYTHON_VERSION}-alpine${ALPINE_VERSION} AS production
# ... production setup ...
```

**Validation Criteria:**
- [ ] Image size < 100MB
- [ ] No high/critical vulnerabilities
- [ ] Runs as non-root user
- [ ] Has health check
- [ ] Starts in < 10 seconds
- [ ] Includes proper logging
- [ ] Environment variables configurable
- [ ] Graceful shutdown handling

---

## 📊 Exercise Results Comparison

**Create a comparison table:**

| Metric | Bad | Good | Excellent | Your Version |
|--------|-----|------|-----------|--------------|
| Size | ~1GB | ~150MB | ~50MB | ? |
| Layers | 15+ | 8-10 | 5-7 | ? |
| Build Time | 5-10min | 2-3min | 1-2min | ? |
| Security | ❌ Root | ✅ Non-root | ✅ Hardened | ? |
| Cache Efficiency | ❌ Poor | ✅ Good | ✅ Excellent | ? |

---

## 🎓 Exercise Completion Checklist

- [ ] Exercise 1: Basic optimization comparison
- [ ] Exercise 2: Multi-stage Node.js build
- [ ] Exercise 3: Security hardening implementation
- [ ] Exercise 4: Layer optimization challenge
- [ ] Exercise 5: Build performance optimization
- [ ] Exercise 6: Image analysis and scanning
- [ ] Challenge: Enterprise production image

**Bonus Points:**
- [ ] Implement BuildKit features
- [ ] Use cache mounts for dependencies
- [ ] Add image signing
- [ ] Create automated security scanning
- [ ] Implement semantic versioning for images

---

**🔧 Troubleshooting Tips:**

1. **Build Fails**: Check Dockerfile syntax and base image availability
2. **Large Images**: Review .dockerignore and remove unnecessary files
3. **Slow Builds**: Optimize layer order and use build cache
4. **Security Issues**: Use minimal base images and scan regularly
5. **Runtime Errors**: Check user permissions and environment variables

Continue to: [Module 3: Container Orchestration & Docker Compose](../03-compose-orchestration/README.md)