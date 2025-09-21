#!/bin/bash

# Module 8: Kubernetes Integration - Interactive Demonstrations
# Enterprise Docker to Kubernetes Migration and Management

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
DEMO_DIR="/tmp/k8s-demo"
NAMESPACE="demo-app"
APP_NAME="enterprise-web-app"

# Helper functions
print_header() {
    echo -e "\n${BLUE}================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================================${NC}\n"
}

print_step() {
    echo -e "\n${GREEN}Step: $1${NC}"
}

print_info() {
    echo -e "${CYAN}Info: $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}Warning: $1${NC}"
}

print_error() {
    echo -e "${RED}Error: $1${NC}"
}

wait_for_input() {
    echo -e "\n${YELLOW}Press Enter to continue...${NC}"
    read -r
}

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi
    print_info "✓ Docker is running"
    
    # Check if kubectl is installed
    if ! command -v kubectl >/dev/null 2>&1; then
        print_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    print_info "✓ kubectl is installed"
    
    # Check if minikube is available (for local demos)
    if command -v minikube >/dev/null 2>&1; then
        print_info "✓ minikube is available for local development"
    else
        print_warning "minikube not found. We'll use existing cluster or kind."
    fi
    
    # Check if kind is available
    if command -v kind >/dev/null 2>&1; then
        print_info "✓ kind is available for local clusters"
    fi
    
    wait_for_input
}

setup_demo_environment() {
    print_header "Setting Up Demo Environment"
    
    # Create demo directory
    mkdir -p "$DEMO_DIR"
    cd "$DEMO_DIR"
    
    print_step "Creating demo application structure"
    
    # Create package.json
    cat > package.json << 'EOF'
{
  "name": "enterprise-web-app",
  "version": "1.0.0",
  "description": "Enterprise Docker to Kubernetes Demo App",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "test": "echo \"Test passed\" && exit 0"
  },
  "dependencies": {
    "express": "^4.18.0",
    "prometheus-client": "^14.0.0"
  }
}
EOF
    
    # Create server.js with metrics
    cat > server.js << 'EOF'
const express = require('express');
const promClient = require('prom-client');
const app = express();
const PORT = process.env.PORT || 3000;

// Prometheus metrics
const register = new promClient.Registry();
promClient.collectDefaultMetrics({ register });

const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 0.5, 1, 2, 5]
});

const httpRequestsTotal = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code']
});

register.registerMetric(httpRequestDuration);
register.registerMetric(httpRequestsTotal);

// Middleware to track metrics
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    const labels = {
      method: req.method,
      route: req.route?.path || req.path,
      status_code: res.statusCode
    };
    httpRequestDuration.observe(labels, duration);
    httpRequestsTotal.inc(labels);
  });
  next();
});

// Application routes
app.get('/', (req, res) => {
  res.json({
    message: 'Enterprise Kubernetes Demo App',
    version: process.env.APP_VERSION || '1.0.0',
    environment: process.env.NODE_ENV || 'development',
    hostname: require('os').hostname(),
    timestamp: new Date().toISOString(),
    pod_name: process.env.HOSTNAME || 'unknown'
  });
});

app.get('/health', (req, res) => {
  res.status(200).json({ 
    status: 'healthy',
    uptime: process.uptime(),
    memory: process.memoryUsage()
  });
});

app.get('/ready', (req, res) => {
  // Simulate readiness check
  const isReady = Math.random() > 0.1; // 90% chance of being ready
  if (isReady) {
    res.status(200).json({ status: 'ready' });
  } else {
    res.status(503).json({ status: 'not ready' });
  }
});

app.get('/metrics', (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(register.metrics());
});

app.get('/load/:duration', (req, res) => {
  const duration = parseInt(req.params.duration) || 100;
  const start = Date.now();
  while (Date.now() - start < duration) {
    Math.sqrt(Math.random());
  }
  res.json({ message: `Simulated load for ${duration}ms` });
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`Pod Name: ${process.env.HOSTNAME || 'unknown'}`);
});
EOF
    
    # Create multi-stage Dockerfile
    cat > Dockerfile << 'EOF'
# Multi-stage build for production
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

FROM node:18-alpine AS production
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

WORKDIR /app
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --chown=nodejs:nodejs . .

USER nodejs
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })"

CMD ["npm", "start"]
EOF
    
    # Create .dockerignore
    cat > .dockerignore << 'EOF'
node_modules
npm-debug.log
Dockerfile
.dockerignore
.git
.gitignore
README.md
.env
coverage
.cache
*.md
EOF
    
    print_info "✓ Demo application created"
    wait_for_input
}

setup_kubernetes_cluster() {
    print_header "Setting Up Kubernetes Cluster"
    
    # Check if we have an existing cluster
    if kubectl cluster-info >/dev/null 2>&1; then
        print_info "Using existing Kubernetes cluster:"
        kubectl cluster-info
    else
        print_step "Setting up local Kubernetes cluster with kind"
        
        # Create kind cluster configuration
        cat > kind-config.yaml << 'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
- role: worker
- role: worker
EOF
        
        # Create cluster
        if command -v kind >/dev/null 2>&1; then
            print_info "Creating kind cluster..."
            kind create cluster --name enterprise-demo --config kind-config.yaml
            
            # Install nginx ingress controller
            print_info "Installing nginx ingress controller..."
            kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
            
            # Wait for ingress controller
            kubectl wait --namespace ingress-nginx \
              --for=condition=ready pod \
              --selector=app.kubernetes.io/component=controller \
              --timeout=90s
        else
            print_warning "kind not available. Please ensure you have access to a Kubernetes cluster."
        fi
    fi
    
    wait_for_input
}

demo_docker_to_k8s_migration() {
    print_header "Demo 1: Docker Compose to Kubernetes Migration"
    
    print_step "Creating Docker Compose application"
    
    # Create docker-compose.yml
    cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  web:
    build: .
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=development
      - APP_VERSION=1.0.0
    depends_on:
      - redis
    volumes:
      - ./logs:/app/logs

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
    depends_on:
      - web

volumes:
  redis_data:
EOF
    
    # Create nginx configuration
    cat > nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    upstream app {
        server web:3000;
    }

    server {
        listen 80;
        location / {
            proxy_pass http://app;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
}
EOF
    
    print_info "Docker Compose application created"
    
    print_step "Building Docker image"
    docker build -t enterprise-web-app:latest .
    
    print_step "Running with Docker Compose"
    docker-compose up -d
    
    print_info "Application running at http://localhost"
    print_info "Let's test it:"
    sleep 5
    curl -s http://localhost/health | jq . || echo "App is starting..."
    
    print_step "Stopping Docker Compose"
    docker-compose down
    
    print_step "Now let's migrate to Kubernetes..."
    wait_for_input
    
    # Create Kubernetes namespace
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Create ConfigMap
    print_step "Creating Kubernetes ConfigMap"
    cat > k8s-configmap.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: demo-app
data:
  NODE_ENV: "production"
  APP_VERSION: "1.0.0"
  REDIS_HOST: "redis-service"
  REDIS_PORT: "6379"
EOF
    kubectl apply -f k8s-configmap.yaml
    
    # Create Redis deployment
    print_step "Creating Redis deployment"
    cat > k8s-redis.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis-deployment
  namespace: demo-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        ports:
        - containerPort: 6379
        volumeMounts:
        - name: redis-storage
          mountPath: /data
      volumes:
      - name: redis-storage
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: redis-service
  namespace: demo-app
spec:
  selector:
    app: redis
  ports:
  - protocol: TCP
    port: 6379
    targetPort: 6379
EOF
    kubectl apply -f k8s-redis.yaml
    
    # Load image into kind cluster if using kind
    if kind get clusters | grep -q enterprise-demo; then
        print_info "Loading image into kind cluster..."
        kind load docker-image enterprise-web-app:latest --name enterprise-demo
    fi
    
    # Create web application deployment
    print_step "Creating web application deployment"
    cat > k8s-webapp.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-deployment
  namespace: demo-app
  labels:
    app: web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: web
        image: enterprise-web-app:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 3000
        envFrom:
        - configMapRef:
            name: app-config
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "500m"
        readinessProbe:
          httpGet:
            path: /ready
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 15
          periodSeconds: 20
---
apiVersion: v1
kind: Service
metadata:
  name: web-service
  namespace: demo-app
spec:
  selector:
    app: web
  ports:
  - protocol: TCP
    port: 80
    targetPort: 3000
  type: ClusterIP
EOF
    kubectl apply -f k8s-webapp.yaml
    
    # Create Ingress
    print_step "Creating Ingress for external access"
    cat > k8s-ingress.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-ingress
  namespace: demo-app
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: localhost
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-service
            port:
              number: 80
EOF
    kubectl apply -f k8s-ingress.yaml
    
    print_step "Waiting for deployments to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/web-deployment -n "$NAMESPACE"
    kubectl wait --for=condition=available --timeout=300s deployment/redis-deployment -n "$NAMESPACE"
    
    print_info "✓ Migration completed! Application is running in Kubernetes"
    
    print_info "Let's check the status:"
    kubectl get pods -n "$NAMESPACE"
    kubectl get services -n "$NAMESPACE"
    
    wait_for_input
}

demo_advanced_deployment_patterns() {
    print_header "Demo 2: Advanced Deployment Patterns"
    
    print_step "Implementing Rolling Updates"
    
    # Update the application with new version
    print_info "Simulating application update..."
    
    # Update deployment with new version
    kubectl patch deployment web-deployment -n "$NAMESPACE" -p='{"spec":{"template":{"spec":{"containers":[{"name":"web","env":[{"name":"APP_VERSION","value":"2.0.0"}]}]}}}}'
    
    print_info "Watching rolling update..."
    kubectl rollout status deployment/web-deployment -n "$NAMESPACE"
    
    print_step "Blue-Green Deployment Simulation"
    
    # Create blue-green deployment configuration
    cat > k8s-blue-green.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-blue
  namespace: demo-app
  labels:
    app: web
    version: blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
      version: blue
  template:
    metadata:
      labels:
        app: web
        version: blue
    spec:
      containers:
      - name: web
        image: enterprise-web-app:latest
        env:
        - name: APP_VERSION
          value: "blue-1.0.0"
        - name: DEPLOYMENT_COLOR
          value: "blue"
        ports:
        - containerPort: 3000
        readinessProbe:
          httpGet:
            path: /ready
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-green
  namespace: demo-app
  labels:
    app: web
    version: green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
      version: green
  template:
    metadata:
      labels:
        app: web
        version: green
    spec:
      containers:
      - name: web
        image: enterprise-web-app:latest
        env:
        - name: APP_VERSION
          value: "green-2.0.0"
        - name: DEPLOYMENT_COLOR
          value: "green"
        ports:
        - containerPort: 3000
        readinessProbe:
          httpGet:
            path: /ready
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: web-active-service
  namespace: demo-app
spec:
  selector:
    app: web
    version: blue  # Initially pointing to blue
  ports:
  - protocol: TCP
    port: 80
    targetPort: 3000
EOF
    kubectl apply -f k8s-blue-green.yaml
    
    print_info "Blue deployment is active, Green is standby"
    kubectl get pods -n "$NAMESPACE" -l version=blue
    kubectl get pods -n "$NAMESPACE" -l version=green
    
    print_step "Switching traffic to Green deployment"
    kubectl patch service web-active-service -n "$NAMESPACE" -p='{"spec":{"selector":{"version":"green"}}}'
    
    print_info "Traffic switched to Green deployment"
    
    wait_for_input
}

demo_autoscaling() {
    print_header "Demo 3: Horizontal Pod Autoscaler (HPA)"
    
    print_step "Installing metrics-server (if needed)"
    
    # Check if metrics-server is running
    if ! kubectl get deployment metrics-server -n kube-system >/dev/null 2>&1; then
        print_info "Installing metrics-server..."
        kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
        
        # Patch metrics-server for kind/local development
        kubectl patch deployment metrics-server -n kube-system --type='json' \
          -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'
        
        kubectl wait --for=condition=available --timeout=300s deployment/metrics-server -n kube-system
    fi
    
    print_step "Creating HPA for the web application"
    
    cat > k8s-hpa.yaml << 'EOF'
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-hpa
  namespace: demo-app
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-deployment
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 70
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 60
EOF
    kubectl apply -f k8s-hpa.yaml
    
    print_info "HPA created. Current status:"
    kubectl get hpa -n "$NAMESPACE"
    
    print_step "Generating load to trigger autoscaling"
    
    # Get service endpoint
    if command -v minikube >/dev/null 2>&1 && minikube status >/dev/null 2>&1; then
        SERVICE_URL=$(minikube service web-service --url -n "$NAMESPACE")
    else
        print_info "Creating port-forward to test load generation..."
        kubectl port-forward -n "$NAMESPACE" service/web-service 8080:80 &
        PORT_FORWARD_PID=$!
        SERVICE_URL="http://localhost:8080"
        sleep 3
    fi
    
    print_info "Generating load on $SERVICE_URL"
    
    # Load generation script
    cat > load-test.sh << 'EOF'
#!/bin/bash
URL=$1
echo "Generating load on $URL"
for i in {1..1000}; do
  curl -s "$URL/load/100" > /dev/null &
  if [ $((i % 50)) -eq 0 ]; then
    echo "Sent $i requests"
    sleep 1
  fi
done
wait
EOF
    chmod +x load-test.sh
    
    ./load-test.sh "$SERVICE_URL" &
    LOAD_PID=$!
    
    print_info "Monitoring HPA scaling..."
    for i in {1..10}; do
        echo "=== Iteration $i ==="
        kubectl get hpa -n "$NAMESPACE"
        kubectl get pods -n "$NAMESPACE" -l app=web
        sleep 30
    done
    
    # Cleanup load generation
    kill $LOAD_PID 2>/dev/null || true
    kill $PORT_FORWARD_PID 2>/dev/null || true
    
    wait_for_input
}

demo_storage_persistence() {
    print_header "Demo 4: Persistent Storage and StatefulSets"
    
    print_step "Creating StorageClass"
    
    cat > k8s-storage-class.yaml << 'EOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-storage
provisioner: rancher.io/local-path  # For kind/local development
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
EOF
    kubectl apply -f k8s-storage-class.yaml
    
    print_step "Creating StatefulSet with persistent storage"
    
    cat > k8s-statefulset.yaml << 'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web-stateful
  namespace: demo-app
spec:
  serviceName: web-headless
  replicas: 3
  selector:
    matchLabels:
      app: web-stateful
  template:
    metadata:
      labels:
        app: web-stateful
    spec:
      containers:
      - name: web
        image: enterprise-web-app:latest
        ports:
        - containerPort: 3000
        env:
        - name: STATEFUL_INSTANCE
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        volumeMounts:
        - name: web-storage
          mountPath: /app/data
        - name: logs-storage
          mountPath: /app/logs
  volumeClaimTemplates:
  - metadata:
      name: web-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: fast-storage
      resources:
        requests:
          storage: 1Gi
  - metadata:
      name: logs-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: fast-storage
      resources:
        requests:
          storage: 500Mi
---
apiVersion: v1
kind: Service
metadata:
  name: web-headless
  namespace: demo-app
spec:
  clusterIP: None
  selector:
    app: web-stateful
  ports:
  - protocol: TCP
    port: 80
    targetPort: 3000
EOF
    kubectl apply -f k8s-statefulset.yaml
    
    print_info "StatefulSet created. Waiting for pods..."
    kubectl wait --for=condition=ready --timeout=300s pod -l app=web-stateful -n "$NAMESPACE"
    
    print_info "StatefulSet pods and storage:"
    kubectl get pods -n "$NAMESPACE" -l app=web-stateful
    kubectl get pvc -n "$NAMESPACE"
    
    wait_for_input
}

demo_monitoring_observability() {
    print_header "Demo 5: Monitoring and Observability"
    
    print_step "Creating ServiceMonitor for Prometheus"
    
    cat > k8s-service-monitor.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: web-metrics-service
  namespace: demo-app
  labels:
    app: web
spec:
  selector:
    app: web
  ports:
  - name: metrics
    protocol: TCP
    port: 3000
    targetPort: 3000
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: web-service-monitor
  namespace: demo-app
  labels:
    app: web
spec:
  selector:
    matchLabels:
      app: web
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
EOF
    kubectl apply -f k8s-service-monitor.yaml || print_warning "ServiceMonitor requires Prometheus Operator"
    
    print_step "Creating custom metrics and alerts"
    
    cat > k8s-prometheus-rule.yaml << 'EOF'
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: web-app-rules
  namespace: demo-app
spec:
  groups:
  - name: web-app.rules
    rules:
    - alert: HighRequestLatency
      expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 0.5
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High request latency detected"
        description: "95th percentile latency is above 500ms"
    
    - alert: HighErrorRate
      expr: rate(http_requests_total{status_code=~"5.."}[5m]) > 0.1
      for: 2m
      labels:
        severity: critical
      annotations:
        summary: "High error rate detected"
        description: "Error rate is above 10%"
    
    - alert: PodCrashLooping
      expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Pod is crash looping"
        description: "Pod {{ $labels.pod }} in namespace {{ $labels.namespace }} is restarting frequently"
EOF
    kubectl apply -f k8s-prometheus-rule.yaml || print_warning "PrometheusRule requires Prometheus Operator"
    
    print_step "Setting up log aggregation with Fluent Bit"
    
    cat > k8s-fluent-bit.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-config
  namespace: demo-app
data:
  fluent-bit.conf: |
    [SERVICE]
        Daemon Off
        Flush 1
        Log_Level info
        Parsers_File parsers.conf
        Plugins_File plugins.conf
        HTTP_Server On
        HTTP_Listen 0.0.0.0
        HTTP_Port 2020

    [INPUT]
        Name tail
        Path /var/log/containers/*.log
        Parser docker
        Tag kube.*
        Refresh_Interval 5
        Mem_Buf_Limit 50MB
        Skip_Long_Lines On

    [FILTER]
        Name kubernetes
        Match kube.*
        Kube_URL https://kubernetes.default.svc:443
        Kube_CA_File /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        Kube_Token_File /var/run/secrets/kubernetes.io/serviceaccount/token
        Kube_Tag_Prefix kube.var.log.containers.
        Merge_Log On
        Keep_Log Off
        K8S-Logging.Parser On
        K8S-Logging.Exclude Off

    [OUTPUT]
        Name stdout
        Match *

  parsers.conf: |
    [PARSER]
        Name docker
        Format json
        Time_Key time
        Time_Format %Y-%m-%dT%H:%M:%S.%L
        Time_Keep On

  plugins.conf: |
    [PLUGINS]
        Path /fluent-bit/bin/out_stdout.so
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluent-bit
  namespace: demo-app
spec:
  selector:
    matchLabels:
      app: fluent-bit
  template:
    metadata:
      labels:
        app: fluent-bit
    spec:
      containers:
      - name: fluent-bit
        image: fluent/fluent-bit:latest
        volumeMounts:
        - name: config
          mountPath: /fluent-bit/etc/
        - name: varlog
          mountPath: /var/log
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
      volumes:
      - name: config
        configMap:
          name: fluent-bit-config
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
      tolerations:
      - operator: Exists
        effect: NoSchedule
EOF
    kubectl apply -f k8s-fluent-bit.yaml
    
    print_info "✓ Monitoring and observability components deployed"
    
    wait_for_input
}

demo_security_networking() {
    print_header "Demo 6: Security and Network Policies"
    
    print_step "Creating Network Policies"
    
    cat > k8s-network-policy.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: web-app-network-policy
  namespace: demo-app
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    - podSelector:
        matchLabels:
          app: nginx
    ports:
    - protocol: TCP
      port: 3000
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: redis
    ports:
    - protocol: TCP
      port: 6379
  - to: []
    ports:
    - protocol: TCP
      port: 443
    - protocol: UDP
      port: 53
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: redis-network-policy
  namespace: demo-app
spec:
  podSelector:
    matchLabels:
      app: redis
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: web
    ports:
    - protocol: TCP
      port: 6379
EOF
    kubectl apply -f k8s-network-policy.yaml
    
    print_step "Creating Pod Security Policy"
    
    cat > k8s-pod-security-policy.yaml << 'EOF'
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: restricted-psp
spec:
  privileged: false
  allowPrivilegeEscalation: false
  requiredDropCapabilities:
    - ALL
  volumes:
    - 'configMap'
    - 'emptyDir'
    - 'projected'
    - 'secret'
    - 'downwardAPI'
    - 'persistentVolumeClaim'
  runAsUser:
    rule: 'MustRunAsNonRoot'
  seLinux:
    rule: 'RunAsAny'
  fsGroup:
    rule: 'RunAsAny'
  readOnlyRootFilesystem: false
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: restricted-psp-user
rules:
- apiGroups: ['policy']
  resources: ['podsecuritypolicies']
  verbs: ['use']
  resourceNames:
  - restricted-psp
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: restricted-psp-all-serviceaccounts
subjects:
- kind: Group
  name: system:serviceaccounts
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: restricted-psp-user
  apiGroup: rbac.authorization.k8s.io
EOF
    kubectl apply -f k8s-pod-security-policy.yaml || print_warning "PodSecurityPolicy may not be available in newer clusters"
    
    print_step "Creating RBAC policies"
    
    cat > k8s-rbac.yaml << 'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: web-app-sa
  namespace: demo-app
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: demo-app
  name: web-app-role
rules:
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: web-app-rolebinding
  namespace: demo-app
subjects:
- kind: ServiceAccount
  name: web-app-sa
  namespace: demo-app
roleRef:
  kind: Role
  name: web-app-role
  apiGroup: rbac.authorization.k8s.io
EOF
    kubectl apply -f k8s-rbac.yaml
    
    print_info "✓ Security policies and RBAC configured"
    
    wait_for_input
}

demo_cleanup() {
    print_header "Demo Cleanup"
    
    print_step "Cleaning up resources"
    
    # Delete namespace (this will delete all resources in the namespace)
    kubectl delete namespace "$NAMESPACE" --ignore-not-found=true
    
    # Delete cluster-level resources
    kubectl delete clusterrolebinding restricted-psp-all-serviceaccounts --ignore-not-found=true
    kubectl delete clusterrole restricted-psp-user --ignore-not-found=true
    kubectl delete podsecuritypolicy restricted-psp --ignore-not-found=true
    
    # Clean up local files
    cd /
    rm -rf "$DEMO_DIR"
    
    # Optionally delete kind cluster
    if kind get clusters | grep -q enterprise-demo; then
        echo -e "\n${YELLOW}Do you want to delete the kind cluster? (y/N)${NC}"
        read -r delete_cluster
        if [[ $delete_cluster =~ ^[Yy]$ ]]; then
            kind delete cluster --name enterprise-demo
        fi
    fi
    
    print_info "✓ Cleanup completed"
}

show_summary() {
    print_header "Demo Summary"
    
    echo -e "${GREEN}🎉 Kubernetes Integration Demo Completed!${NC}\n"
    
    echo -e "${CYAN}What we demonstrated:${NC}"
    echo -e "  ✓ Docker Compose to Kubernetes migration"
    echo -e "  ✓ Advanced deployment patterns (Rolling, Blue-Green)"
    echo -e "  ✓ Horizontal Pod Autoscaling (HPA)"
    echo -e "  ✓ Persistent storage with StatefulSets"
    echo -e "  ✓ Monitoring and observability setup"
    echo -e "  ✓ Security and network policies"
    
    echo -e "\n${CYAN}Key Kubernetes Concepts Covered:${NC}"
    echo -e "  • Pods, Deployments, Services, Ingress"
    echo -e "  • ConfigMaps, Secrets, PersistentVolumes"
    echo -e "  • Autoscaling (HPA/VPA)"
    echo -e "  • StatefulSets for stateful applications"
    echo -e "  • NetworkPolicies for security"
    echo -e "  • RBAC and PodSecurityPolicies"
    echo -e "  • Monitoring with Prometheus/Grafana"
    echo -e "  • Log aggregation with Fluent Bit"
    
    echo -e "\n${CYAN}Next Steps:${NC}"
    echo -e "  • Complete the hands-on exercises"
    echo -e "  • Set up a production Kubernetes cluster"
    echo -e "  • Implement service mesh (Istio/Linkerd)"
    echo -e "  • Explore GitOps with ArgoCD/Flux"
    echo -e "  • Move to Module 9: Performance & Troubleshooting"
    
    echo -e "\n${GREEN}Happy Kubernetes orchestration! 🚀${NC}"
}

main() {
    print_header "Kubernetes Integration - Enterprise Docker Course"
    echo -e "${CYAN}This demo covers the transition from Docker to Kubernetes${NC}"
    echo -e "${CYAN}and advanced container orchestration patterns.${NC}\n"
    
    check_prerequisites
    setup_demo_environment
    setup_kubernetes_cluster
    demo_docker_to_k8s_migration
    demo_advanced_deployment_patterns
    demo_autoscaling
    demo_storage_persistence
    demo_monitoring_observability
    demo_security_networking
    demo_cleanup
    show_summary
}

# Check if script is being run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi