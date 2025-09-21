#!/bin/bash

# Module 9: Performance & Troubleshooting Demonstrations
# Enterprise Docker Training - Performance Optimization and Debugging

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Utility functions
print_header() {
    echo -e "\n${BLUE}===========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===========================================${NC}\n"
}

print_section() {
    echo -e "\n${GREEN}>>> $1${NC}\n"
}

print_warning() {
    echo -e "${YELLOW}WARNING: $1${NC}"
}

print_error() {
    echo -e "${RED}ERROR: $1${NC}"
}

wait_for_user() {
    echo -e "\n${YELLOW}Press Enter to continue...${NC}"
    read
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        exit 1
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_warning "kubectl is not installed. Some demos will be skipped."
    fi
    
    # Check if Kubernetes cluster is available
    if kubectl cluster-info &> /dev/null; then
        echo -e "${GREEN}✓ Kubernetes cluster is available${NC}"
        KUBE_AVAILABLE=true
    else
        print_warning "Kubernetes cluster not available. Some demos will be skipped."
        KUBE_AVAILABLE=false
    fi
    
    echo -e "${GREEN}✓ Docker is available${NC}"
    echo -e "${GREEN}✓ Prerequisites check completed${NC}"
}

# Demo 1: Container Performance Monitoring
demo_container_monitoring() {
    print_header "Demo 1: Container Performance Monitoring"
    
    print_section "Setting up monitoring containers"
    
    # Create a sample application with resource usage
    cat > sample-app.py << 'EOF'
import time
import psutil
import random
from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/health')
def health():
    return jsonify({'status': 'healthy'})

@app.route('/cpu-intensive')
def cpu_intensive():
    # Simulate CPU-intensive task
    start_time = time.time()
    while time.time() - start_time < 5:
        _ = sum(i * i for i in range(10000))
    return jsonify({'task': 'completed', 'duration': '5 seconds'})

@app.route('/memory-intensive')
def memory_intensive():
    # Simulate memory-intensive task
    data = []
    for i in range(100000):
        data.append(random.random() * i)
    return jsonify({'task': 'completed', 'items': len(data)})

@app.route('/metrics')
def metrics():
    cpu_percent = psutil.cpu_percent()
    memory = psutil.virtual_memory()
    return jsonify({
        'cpu_percent': cpu_percent,
        'memory_percent': memory.percent,
        'memory_available': memory.available,
        'memory_used': memory.used
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
EOF

    # Create Dockerfile for sample app
    cat > Dockerfile.monitor << 'EOF'
FROM python:3.9-slim

WORKDIR /app

RUN pip install flask psutil

COPY sample-app.py .

EXPOSE 5000

CMD ["python", "sample-app.py"]
EOF

    print_section "Building sample application"
    docker build -f Dockerfile.monitor -t performance-demo:latest .
    
    print_section "Running container with resource limits"
    docker run -d --name perf-demo \
        --memory=256m \
        --cpus=1.0 \
        -p 5000:5000 \
        performance-demo:latest
    
    echo "Container started. Waiting for application to be ready..."
    sleep 5
    
    print_section "Monitoring container performance"
    echo "Basic container stats:"
    docker stats perf-demo --no-stream
    
    echo -e "\nDetailed resource information:"
    docker inspect perf-demo | jq '.[0].HostConfig | {Memory, CpuShares, CpuQuota, CpuPeriod}'
    
    print_section "Testing application endpoints"
    echo "Health check:"
    curl -s http://localhost:5000/health | jq
    
    echo -e "\nApplication metrics:"
    curl -s http://localhost:5000/metrics | jq
    
    wait_for_user
    
    print_section "Generating load and monitoring"
    echo "Triggering CPU-intensive task..."
    curl -s http://localhost:5000/cpu-intensive &
    
    echo "Monitoring during load:"
    for i in {1..10}; do
        echo "Sample $i:"
        docker stats perf-demo --no-stream
        sleep 2
    done
    
    print_section "Memory usage test"
    echo "Triggering memory-intensive task..."
    curl -s http://localhost:5000/memory-intensive | jq
    
    echo "Final container stats:"
    docker stats perf-demo --no-stream
    
    # Cleanup
    docker stop perf-demo
    docker rm perf-demo
    rm -f sample-app.py Dockerfile.monitor
    
    echo -e "${GREEN}✓ Container monitoring demo completed${NC}"
}

# Demo 2: Resource Optimization
demo_resource_optimization() {
    print_header "Demo 2: Resource Optimization"
    
    print_section "Creating optimized multi-stage Dockerfile"
    
    cat > Dockerfile.optimized << 'EOF'
# Multi-stage build for optimization
FROM node:16-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Production stage
FROM node:16-alpine AS production

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001

WORKDIR /app

# Copy only necessary files
COPY --from=builder --chown=nextjs:nodejs /app/node_modules ./node_modules
COPY --chown=nextjs:nodejs . .

# Remove unnecessary files
RUN rm -rf .git .gitignore README.md Dockerfile* && \
    npm prune --production

USER nextjs

EXPOSE 3000

CMD ["node", "server.js"]
EOF

    # Create a sample Node.js application
    cat > package.json << 'EOF'
{
  "name": "optimized-app",
  "version": "1.0.0",
  "description": "Resource optimized application",
  "main": "server.js",
  "dependencies": {
    "express": "^4.18.0"
  }
}
EOF

    cat > server.js << 'EOF'
const express = require('express');
const app = express();
const port = 3000;

app.get('/', (req, res) => {
    res.json({ 
        message: 'Optimized application',
        memory: process.memoryUsage(),
        uptime: process.uptime()
    });
});

app.get('/health', (req, res) => {
    res.json({ status: 'healthy' });
});

app.listen(port, () => {
    console.log(`Server running on port ${port}`);
});
EOF

    print_section "Building unoptimized vs optimized images"
    
    # Build unoptimized version
    cat > Dockerfile.unoptimized << 'EOF'
FROM node:16

WORKDIR /app
COPY . .
RUN npm install

EXPOSE 3000
CMD ["node", "server.js"]
EOF

    echo "Building unoptimized image..."
    docker build -f Dockerfile.unoptimized -t app:unoptimized .
    
    echo "Building optimized image..."
    docker build -f Dockerfile.optimized -t app:optimized .
    
    print_section "Comparing image sizes"
    echo "Image size comparison:"
    docker images | grep -E "(app:unoptimized|app:optimized)"
    
    print_section "Running performance comparison"
    
    # Run unoptimized version
    echo "Starting unoptimized container..."
    docker run -d --name app-unoptimized \
        --memory=128m \
        --cpus=0.5 \
        -p 3001:3000 \
        app:unoptimized
    
    # Run optimized version
    echo "Starting optimized container..."
    docker run -d --name app-optimized \
        --memory=128m \
        --cpus=0.5 \
        -p 3002:3000 \
        app:optimized
    
    sleep 5
    
    echo "Container resource usage comparison:"
    docker stats app-unoptimized app-optimized --no-stream
    
    echo -e "\nMemory usage from applications:"
    echo "Unoptimized app memory:"
    curl -s http://localhost:3001/ | jq '.memory'
    
    echo "Optimized app memory:"
    curl -s http://localhost:3002/ | jq '.memory'
    
    # Cleanup
    docker stop app-unoptimized app-optimized
    docker rm app-unoptimized app-optimized
    docker rmi app:unoptimized app:optimized
    rm -f Dockerfile.* package.json server.js
    
    echo -e "${GREEN}✓ Resource optimization demo completed${NC}"
}

# Demo 3: Debugging Techniques
demo_debugging_techniques() {
    print_header "Demo 3: Container Debugging Techniques"
    
    print_section "Creating a problematic application"
    
    # Create an application with various issues
    cat > buggy-app.py << 'EOF'
import time
import random
import logging
from flask import Flask, request, jsonify

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

# Simulate memory leak
memory_leak = []

@app.route('/health')
def health():
    return jsonify({'status': 'healthy'})

@app.route('/leak')
def memory_leak_endpoint():
    # Intentional memory leak
    global memory_leak
    for i in range(10000):
        memory_leak.append(f"leaked_data_{i}_{random.random()}")
    return jsonify({'message': 'Memory leaked', 'leak_size': len(memory_leak)})

@app.route('/slow')
def slow_endpoint():
    # Simulate slow response
    time.sleep(random.uniform(5, 10))
    return jsonify({'message': 'Finally responded'})

@app.route('/error')
def error_endpoint():
    # Random errors
    if random.choice([True, False]):
        raise Exception("Random application error")
    return jsonify({'message': 'Success'})

@app.route('/cpu-burn')
def cpu_burn():
    # CPU intensive task
    start = time.time()
    while time.time() - start < 30:
        _ = sum(i * i for i in range(50000))
    return jsonify({'message': 'CPU burn complete'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
EOF

    cat > Dockerfile.debug << 'EOF'
FROM python:3.9-slim

RUN apt-get update && apt-get install -y \
    htop \
    strace \
    tcpdump \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
RUN pip install flask

COPY buggy-app.py .

EXPOSE 5000

CMD ["python", "buggy-app.py"]
EOF

    print_section "Building and running buggy application"
    docker build -f Dockerfile.debug -t buggy-app:latest .
    
    docker run -d --name buggy-container \
        --memory=256m \
        --cpus=1.0 \
        -p 5001:5000 \
        buggy-app:latest
    
    echo "Waiting for application to start..."
    sleep 5
    
    print_section "Debugging techniques demonstration"
    
    echo "1. Container logs inspection:"
    docker logs buggy-container
    
    echo -e "\n2. Container process inspection:"
    docker exec buggy-container ps aux
    
    echo -e "\n3. Real-time resource monitoring:"
    docker stats buggy-container --no-stream
    
    print_section "Triggering issues and debugging"
    
    echo "Triggering memory leak..."
    curl -s http://localhost:5001/leak | jq
    
    echo "Memory usage after leak:"
    docker stats buggy-container --no-stream
    
    echo -e "\n4. Inspecting container filesystem:"
    docker exec buggy-container df -h
    
    echo -e "\n5. Network debugging:"
    docker exec buggy-container netstat -tlnp
    
    print_section "Advanced debugging with exec"
    
    echo "6. Interactive debugging session:"
    echo "Running htop inside container..."
    docker exec buggy-container htop -n 1
    
    echo -e "\n7. System call tracing:"
    echo "Tracing system calls (limited output):"
    timeout 10s docker exec buggy-container strace -c -p 1 2>/dev/null || echo "Strace completed"
    
    print_section "Debug container technique"
    
    echo "8. Using debug container with shared PID namespace:"
    docker run -d --name debug-target \
        --pid=container:buggy-container \
        --network=container:buggy-container \
        alpine:latest sleep 3600
    
    echo "Debugging from debug container:"
    docker exec debug-target ps aux
    
    # Cleanup
    docker stop buggy-container debug-target
    docker rm buggy-container debug-target
    docker rmi buggy-app:latest
    rm -f buggy-app.py Dockerfile.debug
    
    echo -e "${GREEN}✓ Debugging techniques demo completed${NC}"
}

# Demo 4: Kubernetes Performance Monitoring
demo_kubernetes_monitoring() {
    if [ "$KUBE_AVAILABLE" != true ]; then
        print_warning "Kubernetes cluster not available. Skipping Kubernetes monitoring demo."
        return
    fi
    
    print_header "Demo 4: Kubernetes Performance Monitoring"
    
    print_section "Deploying sample application with monitoring"
    
    # Create namespace
    kubectl create namespace perf-demo --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy sample application with resource constraints
    cat > k8s-perf-app.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: perf-demo-app
  namespace: perf-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: perf-demo
  template:
    metadata:
      labels:
        app: perf-demo
    spec:
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: perf-demo-service
  namespace: perf-demo
spec:
  selector:
    app: perf-demo
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF

    kubectl apply -f k8s-perf-app.yaml
    
    echo "Waiting for deployment to be ready..."
    kubectl wait --for=condition=available --timeout=60s deployment/perf-demo-app -n perf-demo
    
    print_section "Kubernetes performance monitoring commands"
    
    echo "1. Pod resource usage:"
    kubectl top pods -n perf-demo
    
    echo -e "\n2. Node resource usage:"
    kubectl top nodes
    
    echo -e "\n3. Pod details and resource constraints:"
    kubectl describe pods -n perf-demo -l app=perf-demo
    
    echo -e "\n4. Resource quotas and limits:"
    kubectl describe namespace perf-demo
    
    print_section "Events and troubleshooting"
    
    echo "5. Recent events in namespace:"
    kubectl get events -n perf-demo --sort-by='.lastTimestamp'
    
    echo -e "\n6. Pod logs:"
    POD_NAME=$(kubectl get pods -n perf-demo -l app=perf-demo -o jsonpath='{.items[0].metadata.name}')
    kubectl logs $POD_NAME -n perf-demo --tail=20
    
    print_section "Resource stress testing"
    
    # Create a stress test pod
    cat > stress-test.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: stress-test
  namespace: perf-demo
spec:
  containers:
  - name: stress
    image: busybox
    command: ["sh", "-c"]
    args:
    - |
      while true; do
        wget -q -O- http://perf-demo-service/ >/dev/null
        sleep 0.1
      done
    resources:
      requests:
        memory: "32Mi"
        cpu: "50m"
      limits:
        memory: "64Mi"
        cpu: "100m"
  restartPolicy: Never
EOF

    kubectl apply -f stress-test.yaml
    
    echo "Running stress test for 30 seconds..."
    sleep 30
    
    echo "Resource usage during stress test:"
    kubectl top pods -n perf-demo
    
    print_section "Horizontal Pod Autoscaler demo"
    
    # Create HPA
    kubectl autoscale deployment perf-demo-app -n perf-demo --cpu-percent=50 --min=2 --max=10
    
    echo "HPA status:"
    kubectl get hpa -n perf-demo
    
    # Cleanup
    kubectl delete namespace perf-demo
    rm -f k8s-perf-app.yaml stress-test.yaml
    
    echo -e "${GREEN}✓ Kubernetes monitoring demo completed${NC}"
}

# Demo 5: Log Analysis and Monitoring
demo_log_monitoring() {
    print_header "Demo 5: Log Analysis and Monitoring"
    
    print_section "Setting up centralized logging"
    
    # Create a log-generating application
    cat > log-app.py << 'EOF'
import time
import random
import json
import logging
from datetime import datetime
from flask import Flask, request

app = Flask(__name__)

# Configure structured logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s %(levelname)s %(message)s'
)

logger = logging.getLogger(__name__)

@app.route('/')
def home():
    logger.info(json.dumps({
        'event': 'page_view',
        'path': '/',
        'user_agent': request.headers.get('User-Agent', 'unknown'),
        'timestamp': datetime.now().isoformat()
    }))
    return {'message': 'Welcome to log demo'}

@app.route('/api/data')
def api_data():
    # Simulate various response times and outcomes
    response_time = random.uniform(0.1, 2.0)
    time.sleep(response_time)
    
    success = random.choice([True, True, True, False])  # 75% success rate
    
    if success:
        logger.info(json.dumps({
            'event': 'api_request',
            'endpoint': '/api/data',
            'status': 'success',
            'response_time': response_time,
            'timestamp': datetime.now().isoformat()
        }))
        return {'data': 'sample data', 'status': 'success'}
    else:
        logger.error(json.dumps({
            'event': 'api_request',
            'endpoint': '/api/data',
            'status': 'error',
            'response_time': response_time,
            'error': 'Internal server error',
            'timestamp': datetime.now().isoformat()
        }))
        return {'error': 'Internal server error'}, 500

@app.route('/health')
def health():
    logger.info(json.dumps({
        'event': 'health_check',
        'status': 'healthy',
        'timestamp': datetime.now().isoformat()
    }))
    return {'status': 'healthy'}

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
EOF

    cat > Dockerfile.logging << 'EOF'
FROM python:3.9-slim

WORKDIR /app
RUN pip install flask

COPY log-app.py .

EXPOSE 5000

CMD ["python", "log-app.py"]
EOF

    print_section "Building and running log application"
    docker build -f Dockerfile.logging -t log-demo:latest .
    
    # Run with custom logging driver
    docker run -d --name log-container \
        --log-driver=json-file \
        --log-opt max-size=10m \
        --log-opt max-file=3 \
        -p 5002:5000 \
        log-demo:latest
    
    echo "Waiting for application to start..."
    sleep 5
    
    print_section "Generating logs and analyzing"
    
    echo "Generating sample traffic..."
    for i in {1..20}; do
        curl -s http://localhost:5002/ > /dev/null
        curl -s http://localhost:5002/api/data > /dev/null
        curl -s http://localhost:5002/health > /dev/null
        sleep 1
    done
    
    echo "Analyzing container logs:"
    echo "1. Recent logs:"
    docker logs log-container --tail=10
    
    echo -e "\n2. Error logs only:"
    docker logs log-container 2>&1 | grep ERROR
    
    echo -e "\n3. Structured log analysis:"
    docker logs log-container 2>&1 | grep -E '(api_request|health_check)' | tail -5
    
    print_section "Log aggregation simulation"
    
    # Simulate log shipping with fluentd
    cat > fluentd.conf << 'EOF'
<source>
  @type forward
  port 24224
  bind 0.0.0.0
</source>

<match docker.**>
  @type file
  path /fluentd/log/docker
  append true
  time_slice_format %Y%m%d
  time_slice_wait 1m
  time_format %Y%m%dT%H%M%S%z
</match>
EOF

    echo "Log configuration created for centralized logging"
    echo "In production, you would use:"
    echo "- ELK Stack (Elasticsearch, Logstash, Kibana)"
    echo "- EFK Stack (Elasticsearch, Fluentd, Kibana)"
    echo "- Grafana Loki with Promtail"
    echo "- Splunk or other enterprise solutions"
    
    print_section "Log retention and rotation"
    
    echo "Container log configuration:"
    docker inspect log-container | jq '.[0].HostConfig.LogConfig'
    
    echo -e "\nLog file location:"
    LOG_PATH=$(docker inspect log-container | jq -r '.[0].LogPath')
    echo "Logs are stored at: $LOG_PATH"
    
    if [ -f "$LOG_PATH" ]; then
        echo "Log file size:"
        ls -lh "$LOG_PATH"
    fi
    
    # Cleanup
    docker stop log-container
    docker rm log-container
    docker rmi log-demo:latest
    rm -f log-app.py Dockerfile.logging fluentd.conf
    
    echo -e "${GREEN}✓ Log monitoring demo completed${NC}"
}

# Demo 6: Performance Testing
demo_performance_testing() {
    print_header "Demo 6: Performance Testing"
    
    print_section "Setting up test application"
    
    # Create a simple web application for testing
    cat > test-app.js << 'EOF'
const express = require('express');
const app = express();
const port = 3000;

let requestCount = 0;
const startTime = Date.now();

// Middleware to track requests
app.use((req, res, next) => {
    requestCount++;
    next();
});

app.get('/', (req, res) => {
    res.json({
        message: 'Performance test endpoint',
        requestCount: requestCount,
        uptime: Date.now() - startTime
    });
});

app.get('/slow', (req, res) => {
    // Simulate slow endpoint
    setTimeout(() => {
        res.json({
            message: 'Slow endpoint response',
            requestCount: requestCount
        });
    }, 1000);
});

app.get('/cpu', (req, res) => {
    // CPU intensive endpoint
    const start = Date.now();
    let sum = 0;
    for (let i = 0; i < 1000000; i++) {
        sum += Math.sqrt(i);
    }
    const duration = Date.now() - start;
    
    res.json({
        message: 'CPU intensive task completed',
        duration: duration,
        result: sum
    });
});

app.get('/memory', (req, res) => {
    // Memory usage endpoint
    const used = process.memoryUsage();
    res.json({
        message: 'Memory usage info',
        memory: {
            rss: Math.round(used.rss / 1024 / 1024) + ' MB',
            heapTotal: Math.round(used.heapTotal / 1024 / 1024) + ' MB',
            heapUsed: Math.round(used.heapUsed / 1024 / 1024) + ' MB'
        }
    });
});

app.listen(port, () => {
    console.log(`Test app running on port ${port}`);
});
EOF

    cat > package-test.json << 'EOF'
{
  "name": "performance-test-app",
  "version": "1.0.0",
  "main": "test-app.js",
  "dependencies": {
    "express": "^4.18.0"
  }
}
EOF

    cat > Dockerfile.test << 'EOF'
FROM node:16-alpine

WORKDIR /app
COPY package-test.json package.json
RUN npm install

COPY test-app.js .

EXPOSE 3000

CMD ["node", "test-app.js"]
EOF

    print_section "Building and running test application"
    docker build -f Dockerfile.test -t test-app:latest .
    
    docker run -d --name test-container \
        --memory=256m \
        --cpus=1.0 \
        -p 3003:3000 \
        test-app:latest
    
    echo "Waiting for application to start..."
    sleep 5
    
    print_section "Basic performance testing"
    
    echo "1. Baseline response test:"
    time curl -s http://localhost:3003/ | jq
    
    echo -e "\n2. Load testing with curl:"
    echo "Testing concurrent requests..."
    
    # Simple load test with curl
    for i in {1..10}; do
        curl -s http://localhost:3003/ > /dev/null &
    done
    wait
    
    echo "Memory usage after load:"
    curl -s http://localhost:3003/memory | jq
    
    print_section "Advanced performance testing simulation"
    
    # Simulate Apache Bench (ab) testing
    echo "3. Simulating ab-style load testing:"
    echo "Testing slow endpoint under load..."
    
    # Background monitoring
    docker stats test-container --no-stream &
    STATS_PID=$!
    
    # Generate load
    for i in {1..20}; do
        curl -s http://localhost:3003/slow > /dev/null &
        if [ $((i % 5)) -eq 0 ]; then
            echo "Sent $i requests..."
        fi
    done
    
    echo "Waiting for requests to complete..."
    wait
    
    # Stop background monitoring
    kill $STATS_PID 2>/dev/null || true
    
    echo -e "\n4. CPU intensive load test:"
    echo "Testing CPU endpoint..."
    
    start_time=$(date +%s)
    for i in {1..5}; do
        curl -s http://localhost:3003/cpu | jq '.duration' &
    done
    wait
    end_time=$(date +%s)
    
    echo "Total time for 5 CPU-intensive requests: $((end_time - start_time)) seconds"
    
    print_section "Performance testing best practices"
    
    echo "Performance testing tools you should use:"
    echo "1. Apache Bench (ab): Simple HTTP load testing"
    echo "2. wrk: Modern HTTP benchmarking tool"
    echo "3. JMeter: Comprehensive load testing"
    echo "4. k6: Modern load testing for developers"
    echo "5. Artillery: Modern load testing toolkit"
    
    echo -e "\nExample commands:"
    echo "ab -n 1000 -c 10 http://localhost:3003/"
    echo "wrk -t12 -c400 -d30s http://localhost:3003/"
    echo "k6 run --vus 10 --duration 30s script.js"
    
    print_section "Container resource monitoring during load"
    
    echo "Final container statistics:"
    docker stats test-container --no-stream
    
    echo -e "\nApplication metrics:"
    curl -s http://localhost:3003/ | jq
    curl -s http://localhost:3003/memory | jq
    
    # Cleanup
    docker stop test-container
    docker rm test-container
    docker rmi test-app:latest
    rm -f test-app.js package-test.json Dockerfile.test
    
    echo -e "${GREEN}✓ Performance testing demo completed${NC}"
}

# Main execution
main() {
    print_header "Module 9: Performance & Troubleshooting Demonstrations"
    
    check_prerequisites
    
    echo -e "\nAvailable demonstrations:"
    echo "1. Container Performance Monitoring"
    echo "2. Resource Optimization"
    echo "3. Debugging Techniques"
    echo "4. Kubernetes Performance Monitoring"
    echo "5. Log Analysis and Monitoring"
    echo "6. Performance Testing"
    echo "7. Run all demonstrations"
    
    echo -e "\n${YELLOW}Choose a demonstration (1-7):${NC}"
    read -r choice
    
    case $choice in
        1)
            demo_container_monitoring
            ;;
        2)
            demo_resource_optimization
            ;;
        3)
            demo_debugging_techniques
            ;;
        4)
            demo_kubernetes_monitoring
            ;;
        5)
            demo_log_monitoring
            ;;
        6)
            demo_performance_testing
            ;;
        7)
            demo_container_monitoring
            demo_resource_optimization
            demo_debugging_techniques
            demo_kubernetes_monitoring
            demo_log_monitoring
            demo_performance_testing
            ;;
        *)
            print_error "Invalid choice. Please run the script again and choose 1-7."
            exit 1
            ;;
    esac
    
    print_header "All Demonstrations Completed Successfully!"
    echo -e "${GREEN}You have successfully completed the Performance & Troubleshooting demonstrations.${NC}"
    echo -e "${GREEN}These skills are essential for maintaining containerized applications in production.${NC}"
    echo -e "\n${BLUE}Next steps:${NC}"
    echo "1. Practice these techniques with your own applications"
    echo "2. Set up monitoring in your development environment"
    echo "3. Create performance baselines for your applications"
    echo "4. Implement automated performance testing in your CI/CD pipeline"
    echo "5. Proceed to Module 10: Enterprise Architecture Patterns"
}

# Run main function
main "$@"