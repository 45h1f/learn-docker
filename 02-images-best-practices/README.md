# Module 2: Docker Images & Dockerfile Best Practices

## 🎯 Learning Objectives
- Master Dockerfile syntax and best practices
- Implement multi-stage builds for optimization
- Understand layer caching and optimization
- Apply security best practices in image building
- Learn image scanning and vulnerability management

## 📖 Theory: Docker Images Deep Dive

### Image Layers and Caching
Docker images are built using a layered filesystem. Each instruction in your Dockerfile creates a new layer:

```dockerfile
FROM python:3.9-alpine    # Layer 1: Base image
RUN apk add --no-cache curl # Layer 2: Install curl  
COPY requirements.txt .    # Layer 3: Copy requirements
RUN pip install -r requirements.txt # Layer 4: Install dependencies
COPY . .                   # Layer 5: Copy application code
CMD ["python", "app.py"]   # Layer 6: Default command
```

**Key Concepts:**
- Layers are cached and reused if unchanged
- Each layer adds to the final image size
- Order matters for cache efficiency
- Only the topmost changed layer and all layers above it are rebuilt

### Multi-Stage Builds
Multi-stage builds allow you to use multiple `FROM` statements in a single Dockerfile:

**Benefits:**
- Smaller production images
- Separate build and runtime environments
- Better security (no build tools in production)
- Cleaner separation of concerns

## 🛠️ Dockerfile Best Practices

### 1. Base Image Selection

| Image Type | Size | Use Case | Example |
|------------|------|----------|---------|
| Full OS | ~200MB+ | Development, debugging | `ubuntu:20.04` |
| Language-specific | ~100-150MB | Standard applications | `python:3.9` |
| Slim variants | ~50-100MB | Production, balanced | `python:3.9-slim` |
| Alpine variants | ~20-50MB | Minimal, production | `python:3.9-alpine` |
| Distroless | ~10-30MB | Security-focused | `gcr.io/distroless/python3` |

### 2. Layer Optimization Strategies

**❌ Poor Caching:**
```dockerfile
COPY . .                    # Changes frequently
RUN pip install -r requirements.txt  # Rebuilds every time
```

**✅ Good Caching:**
```dockerfile
COPY requirements.txt .     # Changes rarely
RUN pip install -r requirements.txt  # Cached most of the time
COPY . .                    # Changes frequently, but deps are cached
```

**❌ Too Many Layers:**
```dockerfile
RUN apt-get update
RUN apt-get install -y curl
RUN apt-get install -y git
RUN apt-get clean
```

**✅ Optimized Layers:**
```dockerfile
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
```

### 3. Security Best Practices

**Run as Non-Root User:**
```dockerfile
# Create user
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Set ownership
RUN chown -R appuser:appuser /app

# Switch to non-root
USER appuser
```

**Scan for Vulnerabilities:**
```bash
# Using Docker Scout (built-in)
docker scout cves myapp:latest

# Using Trivy
trivy image myapp:latest

# Using Snyk
snyk container test myapp:latest
```

## 🔧 Hands-on Lab: Image Optimization

Let's compare different approaches to building the same application:

### Step 1: Build All Variants
```bash
cd /home/ashif/Projects/personal/Docker/lean_docker/02-images-best-practices
./compare-builds.sh
```

This script will build three versions:
1. **Bad**: Ubuntu-based, inefficient
2. **Good**: Python slim, optimized  
3. **Excellent**: Multi-stage, Alpine-based

### Step 2: Analyze Results
Compare the output for:
- **Image sizes** (Bad: ~1GB, Good: ~150MB, Excellent: ~50MB)
- **Build times** 
- **Security** (root vs non-root user)
- **Layer count**

### Step 3: Test the Optimized Application
```bash
# Run the excellent version
docker run -d --name optimized-app -p 8080:5000 flask-app:excellent

# Test the application
curl http://localhost:8080/health
curl http://localhost:8080/info

# Open in browser
echo "Visit: http://localhost:8080"
```

## 🏗️ Multi-Stage Build Examples

### Example 1: Node.js Application
```dockerfile
# Build stage
FROM node:16-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

# Production stage  
FROM node:16-alpine AS production
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001
WORKDIR /app
COPY --from=builder --chown=nextjs:nodejs /app/node_modules ./node_modules
COPY --chown=nextjs:nodejs . .
USER nextjs
EXPOSE 3000
CMD ["node", "server.js"]
```

### Example 2: Go Application
```dockerfile
# Build stage
FROM golang:1.19-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o main .

# Production stage
FROM alpine:latest AS production
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/main .
CMD ["./main"]
```

### Example 3: Java Application
```dockerfile
# Build stage
FROM openjdk:11-jdk-slim AS builder
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN ./mvnw clean package -DskipTests

# Production stage
FROM openjdk:11-jre-slim AS production
RUN addgroup --system javauser && adduser --system --group javauser
WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar
RUN chown javauser:javauser app.jar
USER javauser
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

## 🔍 Image Analysis Tools

### 1. Docker Scout (Built-in)
```bash
# Enable Docker Scout
docker scout quickview

# Scan image for vulnerabilities
docker scout cves myapp:latest

# Compare images
docker scout compare --to myapp:v1.0 myapp:v2.0

# Get recommendations
docker scout recommendations myapp:latest
```

### 2. Dive - Explore Image Layers
```bash
# Install dive
wget https://github.com/wagoodman/dive/releases/download/v0.10.0/dive_0.10.0_linux_amd64.deb
sudo apt install ./dive_0.10.0_linux_amd64.deb

# Analyze image layers
dive myapp:latest
```

### 3. Trivy - Vulnerability Scanner
```bash
# Install trivy
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin

# Scan image
trivy image myapp:latest

# Scan with specific severity
trivy image --severity HIGH,CRITICAL myapp:latest

# Output as JSON
trivy image --format json myapp:latest
```

## 📊 Image Size Optimization Techniques

### 1. Use .dockerignore
```bash
# .dockerignore
node_modules/
npm-debug.log*
.git/
.DS_Store
README.md
Dockerfile*
docker-compose*
.dockerignore
```

### 2. Multi-stage with Specific Copying
```dockerfile
# Only copy production files
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package.json ./
COPY --from=builder /app/node_modules ./node_modules
```

### 3. Remove Package Managers and Caches
```dockerfile
# Alpine
RUN apk add --no-cache package && \
    # ... use package ... && \
    apk del package

# Ubuntu/Debian
RUN apt-get update && \
    apt-get install -y --no-install-recommends package && \
    # ... use package ... && \
    apt-get remove -y package && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
```

## 🚨 Common Pitfalls and Solutions

### 1. Cache Invalidation
**Problem:** Dependencies reinstall every build
**Solution:** Copy dependency files first
```dockerfile
# ❌ Bad
COPY . .
RUN pip install -r requirements.txt

# ✅ Good  
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
```

### 2. Large Image Sizes
**Problem:** Images are too large
**Solutions:**
- Use Alpine or slim base images
- Implement multi-stage builds
- Remove unnecessary packages
- Use .dockerignore

### 3. Security Vulnerabilities
**Problem:** Running as root, outdated packages
**Solutions:**
- Create and use non-root user
- Regularly update base images
- Scan images for vulnerabilities
- Use minimal base images

### 4. Slow Builds
**Problem:** Builds take too long
**Solutions:**
- Optimize layer order for caching
- Use multi-stage builds
- Minimize context size with .dockerignore
- Use build cache mounts

## 📝 Production Dockerfile Template

Here's a production-ready Dockerfile template:

```dockerfile
# syntax=docker/dockerfile:1
# Multi-stage build for production optimization

# Build stage
FROM python:3.9-alpine AS builder

# Install build dependencies
RUN apk add --no-cache \
    gcc \
    musl-dev \
    linux-headers \
    postgresql-dev

# Create virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Production stage
FROM python:3.9-alpine AS production

# Install runtime dependencies only
RUN apk add --no-cache \
    postgresql-libs \
    curl

# Create non-root user
RUN addgroup -g 1001 -S appuser && \
    adduser -S -D -H -u 1001 -h /app -s /sbin/nologin -G appuser appuser

# Copy virtual environment from builder
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Set working directory
WORKDIR /app

# Copy application code
COPY --chown=appuser:appuser . .

# Switch to non-root user
USER appuser

# Set environment variables
ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1
ENV ENVIRONMENT=production

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Use production server
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "4", "app:app"]
```

## 🧪 Practice Exercises

### Exercise 1: Optimize a Node.js App
Create a multi-stage Dockerfile for a Node.js application that:
- Uses separate stages for dependencies and production
- Runs as non-root user
- Has a health check
- Is under 100MB

### Exercise 2: Security Hardening
Take an existing Dockerfile and apply security best practices:
- Non-root user
- Minimal base image
- Vulnerability scanning
- Secret management

### Exercise 3: Build Performance
Optimize a Dockerfile for build speed:
- Layer caching optimization
- Minimal context
- Parallel operations where possible

### Exercise 4: Size Optimization Challenge
Create the smallest possible image for a Python Flask app:
- Target: Under 50MB
- Must include all dependencies
- Must be functional

## 🎓 Module Summary

You've learned:
- ✅ Dockerfile best practices and optimization techniques
- ✅ Multi-stage builds for smaller, more secure images
- ✅ Layer caching strategies for faster builds
- ✅ Security best practices in image building
- ✅ Image analysis and vulnerability scanning
- ✅ Production-ready Dockerfile patterns

## 🔄 Next Steps

Ready for Module 3? You'll learn:
- Docker Compose for multi-container applications
- Service definitions and dependencies
- Environment-specific configurations
- Container orchestration patterns

---

**💡 Pro Tip**: Always scan your images for vulnerabilities before deploying to production. Use `docker scout cves` or `trivy image` as part of your CI/CD pipeline!

Continue to: [Module 3: Container Orchestration & Docker Compose](../03-compose-orchestration/README.md)