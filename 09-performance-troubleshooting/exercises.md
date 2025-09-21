# Module 9: Performance & Troubleshooting - Exercises

## Overview
These exercises will help you master container performance optimization, debugging techniques, and enterprise troubleshooting strategies. Each exercise builds practical skills needed for production container environments.

## Prerequisites
- Completion of Modules 1-8
- Docker and Kubernetes access
- Basic understanding of Linux system administration
- Familiarity with monitoring concepts

---

## Exercise 1: Container Performance Monitoring Setup

### Objective
Set up comprehensive monitoring for containerized applications using Prometheus, Grafana, and cAdvisor.

### Tasks

#### Task 1.1: Deploy Monitoring Stack
Create a monitoring stack with Prometheus, Grafana, and cAdvisor.

```bash
# Create monitoring namespace
kubectl create namespace monitoring

# Deploy Prometheus
cat > prometheus-config.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
    
    scrape_configs:
    - job_name: 'prometheus'
      static_configs:
      - targets: ['localhost:9090']
    
    - job_name: 'cadvisor'
      static_configs:
      - targets: ['cadvisor:8080']
    
    - job_name: 'node-exporter'
      static_configs:
      - targets: ['node-exporter:9100']
    
    - job_name: 'kubernetes-pods'
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:latest
        ports:
        - containerPort: 9090
        volumeMounts:
        - name: config
          mountPath: /etc/prometheus
        args:
        - '--config.file=/etc/prometheus/prometheus.yml'
        - '--storage.tsdb.path=/prometheus'
        - '--web.console.libraries=/etc/prometheus/console_libraries'
        - '--web.console.templates=/etc/prometheus/consoles'
        - '--storage.tsdb.retention.time=200h'
        - '--web.enable-lifecycle'
      volumes:
      - name: config
        configMap:
          name: prometheus-config
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: monitoring
spec:
  selector:
    app: prometheus
  ports:
  - port: 9090
    targetPort: 9090
  type: ClusterIP
EOF

kubectl apply -f prometheus-config.yaml

# Deploy cAdvisor
cat > cadvisor.yaml << 'EOF'
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: cadvisor
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: cadvisor
  template:
    metadata:
      labels:
        app: cadvisor
    spec:
      containers:
      - name: cadvisor
        image: gcr.io/cadvisor/cadvisor:latest
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: rootfs
          mountPath: /rootfs
          readOnly: true
        - name: var-run
          mountPath: /var/run
          readOnly: true
        - name: sys
          mountPath: /sys
          readOnly: true
        - name: docker
          mountPath: /var/lib/docker
          readOnly: true
        - name: disk
          mountPath: /dev/disk
          readOnly: true
      volumes:
      - name: rootfs
        hostPath:
          path: /
      - name: var-run
        hostPath:
          path: /var/run
      - name: sys
        hostPath:
          path: /sys
      - name: docker
        hostPath:
          path: /var/lib/docker
      - name: disk
        hostPath:
          path: /dev/disk
---
apiVersion: v1
kind: Service
metadata:
  name: cadvisor
  namespace: monitoring
spec:
  selector:
    app: cadvisor
  ports:
  - port: 8080
    targetPort: 8080
EOF

kubectl apply -f cadvisor.yaml
```

#### Task 1.2: Deploy Grafana
Set up Grafana with pre-configured dashboards.

```bash
cat > grafana.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:latest
        ports:
        - containerPort: 3000
        env:
        - name: GF_SECURITY_ADMIN_PASSWORD
          value: "admin123"
        volumeMounts:
        - name: grafana-storage
          mountPath: /var/lib/grafana
      volumes:
      - name: grafana-storage
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: monitoring
spec:
  selector:
    app: grafana
  ports:
  - port: 3000
    targetPort: 3000
  type: NodePort
EOF

kubectl apply -f grafana.yaml
```

#### Task 1.3: Create Custom Metrics Application
Deploy an application that exposes custom metrics.

```python
# Create metrics-app.py
from prometheus_client import start_http_server, Counter, Histogram, Gauge
import time
import random
from flask import Flask

app = Flask(__name__)

# Prometheus metrics
REQUEST_COUNT = Counter('app_requests_total', 'Total app requests', ['method', 'endpoint'])
REQUEST_LATENCY = Histogram('app_request_duration_seconds', 'Request latency')
ACTIVE_USERS = Gauge('app_active_users', 'Number of active users')
ERROR_RATE = Counter('app_errors_total', 'Total application errors')

@app.route('/')
@REQUEST_LATENCY.time()
def home():
    REQUEST_COUNT.labels(method='GET', endpoint='/').inc()
    # Simulate some processing time
    time.sleep(random.uniform(0.1, 0.5))
    return {'message': 'Hello from metrics app'}

@app.route('/api/users')
@REQUEST_LATENCY.time()
def users():
    REQUEST_COUNT.labels(method='GET', endpoint='/api/users').inc()
    
    # Simulate active users
    ACTIVE_USERS.set(random.randint(10, 100))
    
    # Simulate errors occasionally
    if random.random() < 0.1:  # 10% error rate
        ERROR_RATE.inc()
        return {'error': 'Service unavailable'}, 500
    
    return {'users': ['user1', 'user2', 'user3']}

@app.route('/health')
def health():
    return {'status': 'healthy'}

if __name__ == '__main__':
    # Start Prometheus metrics server
    start_http_server(8000)
    app.run(host='0.0.0.0', port=5000)
```

```dockerfile
# Dockerfile for metrics app
FROM python:3.9-slim

WORKDIR /app

RUN pip install flask prometheus_client

COPY metrics-app.py .

EXPOSE 5000 8000

CMD ["python", "metrics-app.py"]
```

#### Task 1.4: Configure Monitoring Alerts
Set up alerting rules for common issues.

```yaml
# Create alerting-rules.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: alerting-rules
  namespace: monitoring
data:
  rules.yml: |
    groups:
    - name: container.rules
      rules:
      - alert: HighCPUUsage
        expr: rate(container_cpu_usage_seconds_total[5m]) * 100 > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage detected"
          description: "Container {{ $labels.name }} has high CPU usage"
      
      - alert: HighMemoryUsage
        expr: (container_memory_usage_bytes / container_spec_memory_limit_bytes) * 100 > 90
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High memory usage detected"
          description: "Container {{ $labels.name }} is using {{ $value }}% of memory"
      
      - alert: PodCrashLooping
        expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Pod is crash looping"
          description: "Pod {{ $labels.pod }} is restarting frequently"
```

### Expected Outcomes
- Functional monitoring stack with Prometheus and Grafana
- Custom metrics collection from application
- Alert rules for common container issues
- Grafana dashboards showing container metrics

### Validation
1. Access Grafana dashboard and verify data collection
2. Generate load on the metrics application
3. Observe metrics in Prometheus
4. Test alert triggering by resource exhaustion

---

## Exercise 2: Resource Optimization and Right-sizing

### Objective
Learn to optimize container resource allocation and implement autoscaling strategies.

### Tasks

#### Task 2.1: Resource Profiling
Profile an application to determine optimal resource requirements.

```bash
# Deploy test application with various resource configurations
cat > resource-test.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resource-test-small
spec:
  replicas: 3
  selector:
    matchLabels:
      app: resource-test
      size: small
  template:
    metadata:
      labels:
        app: resource-test
        size: small
    spec:
      containers:
      - name: app
        image: nginx:alpine
        resources:
          requests:
            memory: "32Mi"
            cpu: "50m"
          limits:
            memory: "64Mi"
            cpu: "100m"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resource-test-medium
spec:
  replicas: 3
  selector:
    matchLabels:
      app: resource-test
      size: medium
  template:
    metadata:
      labels:
        app: resource-test
        size: medium
    spec:
      containers:
      - name: app
        image: nginx:alpine
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resource-test-large
spec:
  replicas: 3
  selector:
    matchLabels:
      app: resource-test
      size: large
  template:
    metadata:
      labels:
        app: resource-test
        size: large
    spec:
      containers:
      - name: app
        image: nginx:alpine
        resources:
          requests:
            memory: "128Mi"
            cpu: "200m"
          limits:
            memory: "256Mi"
            cpu: "500m"
EOF

kubectl apply -f resource-test.yaml

# Monitor resource usage
kubectl top pods -l app=resource-test
kubectl describe nodes
```

#### Task 2.2: Implement Vertical Pod Autoscaler (VPA)
Set up VPA to automatically adjust resource requests.

```yaml
# Install VPA (if not already installed)
# kubectl apply -f https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler/deploy

# Create VPA configuration
cat > vpa-config.yaml << 'EOF'
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: nginx-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: resource-test-medium
  updatePolicy:
    updateMode: "Auto"
  resourcePolicy:
    containerPolicies:
    - containerName: app
      maxAllowed:
        cpu: 1
        memory: 500Mi
      minAllowed:
        cpu: 100m
        memory: 50Mi
      controlledResources: ["cpu", "memory"]
EOF

kubectl apply -f vpa-config.yaml
```

#### Task 2.3: Horizontal Pod Autoscaler (HPA)
Configure HPA for automatic scaling based on metrics.

```bash
# Create HPA for CPU-based scaling
kubectl autoscale deployment resource-test-medium --cpu-percent=50 --min=2 --max=10

# Create custom HPA with memory metrics
cat > custom-hpa.yaml << 'EOF'
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: custom-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: resource-test-medium
  minReplicas: 2
  maxReplicas: 20
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
        value: 10
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
      - type: Pods
        value: 4
        periodSeconds: 15
      selectPolicy: Max
EOF

kubectl apply -f custom-hpa.yaml
```

#### Task 2.4: Load Testing and Optimization
Perform load testing to validate scaling behavior.

```python
# Create load-generator.py
import requests
import threading
import time
import random

def generate_load(url, duration=300, threads=10):
    """Generate load on the target URL"""
    def worker():
        end_time = time.time() + duration
        while time.time() < end_time:
            try:
                response = requests.get(url, timeout=5)
                print(f"Status: {response.status_code}, Time: {response.elapsed.total_seconds():.3f}s")
            except Exception as e:
                print(f"Error: {e}")
            time.sleep(random.uniform(0.1, 1.0))
    
    # Start worker threads
    threads_list = []
    for i in range(threads):
        t = threading.Thread(target=worker)
        t.start()
        threads_list.append(t)
    
    # Wait for all threads to complete
    for t in threads_list:
        t.join()

if __name__ == "__main__":
    # Replace with your service URL
    service_url = "http://your-service-url"
    generate_load(service_url, duration=600, threads=20)
```

#### Task 2.5: Resource Optimization Analysis
Analyze and optimize based on collected metrics.

```bash
# Analyze resource usage patterns
kubectl top pods -l app=resource-test --sort-by=memory
kubectl top pods -l app=resource-test --sort-by=cpu

# Get detailed metrics
kubectl describe hpa custom-hpa
kubectl describe vpa nginx-vpa

# Export resource usage for analysis
kubectl get pods -l app=resource-test -o json | jq '.items[] | {name: .metadata.name, requests: .spec.containers[0].resources.requests, limits: .spec.containers[0].resources.limits}'
```

### Expected Outcomes
- Optimized resource allocation for different workload patterns
- Functional VPA and HPA configurations
- Understanding of scaling behavior under load
- Performance baselines for different resource configurations

### Validation
1. Verify VPA recommendations and automatic adjustments
2. Test HPA scaling under load
3. Compare performance across different resource configurations
4. Document optimal resource settings for the workload

---

## Exercise 3: Advanced Debugging and Troubleshooting

### Objective
Master advanced debugging techniques for container and Kubernetes issues.

### Tasks

#### Task 3.1: Debug Container Startup Issues
Troubleshoot common container startup problems.

```bash
# Create problematic deployment
cat > problematic-app.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: problematic-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: problematic-app
  template:
    metadata:
      labels:
        app: problematic-app
    spec:
      containers:
      - name: app
        image: problematic-image:latest  # Non-existent image
        ports:
        - containerPort: 8080
        env:
        - name: DATABASE_URL
          value: "postgres://user:pass@nonexistent-db:5432/app"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
EOF

kubectl apply -f problematic-app.yaml

# Debug the issues
echo "Debugging deployment issues:"
kubectl get deployments
kubectl get pods -l app=problematic-app
kubectl describe pods -l app=problematic-app
kubectl get events --sort-by='.lastTimestamp'
```

#### Task 3.2: Network Troubleshooting
Debug service-to-service communication issues.

```bash
# Create services with connectivity issues
cat > network-debug.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
spec:
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: httpd:alpine
        ports:
        - containerPort: 8080  # Wrong port for httpd
---
apiVersion: v1
kind: Service
metadata:
  name: backend-service
spec:
  selector:
    app: backend-wrong  # Wrong selector
  ports:
  - port: 8080
    targetPort: 80
EOF

kubectl apply -f network-debug.yaml

# Debug network connectivity
echo "Network debugging steps:"
kubectl get services
kubectl describe service backend-service
kubectl get endpoints backend-service

# Test connectivity from frontend pod
FRONTEND_POD=$(kubectl get pods -l app=frontend -o jsonpath='{.items[0].metadata.name}')
kubectl exec $FRONTEND_POD -- nslookup backend-service
kubectl exec $FRONTEND_POD -- wget -O- --timeout=5 http://backend-service:8080
```

#### Task 3.3: Storage Troubleshooting
Debug persistent volume and storage issues.

```bash
# Create storage with issues
cat > storage-debug.yaml << 'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: problematic-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1000Gi  # Unrealistic size
  storageClassName: nonexistent-class
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: storage-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: storage-app
  template:
    metadata:
      labels:
        app: storage-app
    spec:
      containers:
      - name: app
        image: busybox
        command: ["sleep", "3600"]
        volumeMounts:
        - name: data
          mountPath: /data
        - name: nonexistent
          mountPath: /missing
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: problematic-pvc
      - name: nonexistent
        configMap:
          name: missing-configmap
EOF

kubectl apply -f storage-debug.yaml

# Debug storage issues
echo "Storage debugging:"
kubectl get pvc
kubectl describe pvc problematic-pvc
kubectl get pods -l app=storage-app
kubectl describe pods -l app=storage-app
kubectl get events --field-selector involvedObject.name=problematic-pvc
```

#### Task 3.4: Performance Debugging
Debug performance issues using profiling tools.

```python
# Create performance-debug-app.py
import time
import psutil
import threading
from flask import Flask, request, jsonify

app = Flask(__name__)

# Simulate memory leak
leaked_data = []

@app.route('/leak')
def memory_leak():
    global leaked_data
    # Add data to simulate memory leak
    for i in range(10000):
        leaked_data.append(f"data_{i}_{time.time()}")
    return jsonify({'leaked_items': len(leaked_data)})

@app.route('/cpu-burn')
def cpu_burn():
    # CPU intensive operation
    def burn_cpu():
        end_time = time.time() + 10
        while time.time() < end_time:
            _ = sum(i * i for i in range(10000))
    
    threads = []
    for _ in range(4):  # Create 4 threads
        t = threading.Thread(target=burn_cpu)
        t.start()
        threads.append(t)
    
    for t in threads:
        t.join()
    
    return jsonify({'status': 'CPU burn complete'})

@app.route('/slow-query')
def slow_query():
    # Simulate slow database query
    time.sleep(5)
    return jsonify({'result': 'slow query result'})

@app.route('/metrics')
def metrics():
    process = psutil.Process()
    return jsonify({
        'cpu_percent': process.cpu_percent(),
        'memory_info': process.memory_info()._asdict(),
        'num_threads': process.num_threads(),
        'open_files': len(process.open_files())
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```

```bash
# Debug performance issues
echo "Performance debugging workflow:"

# 1. Monitor resource usage
kubectl top pods
kubectl top nodes

# 2. Check for resource limits
kubectl describe pods -l app=performance-app

# 3. Analyze container logs for performance issues
kubectl logs -l app=performance-app --tail=100

# 4. Use exec to run profiling tools inside container
POD_NAME=$(kubectl get pods -l app=performance-app -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD_NAME -- top -b -n1
kubectl exec $POD_NAME -- ps aux
kubectl exec $POD_NAME -- netstat -tulpn
```

#### Task 3.5: Debug Container using Debug Container
Use Kubernetes debug containers for troubleshooting.

```bash
# Create a minimal pod with issues
cat > minimal-pod.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: minimal-app
spec:
  containers:
  - name: app
    image: busybox
    command: ["sleep", "3600"]
    resources:
      limits:
        memory: "64Mi"
        cpu: "100m"
EOF

kubectl apply -f minimal-pod.yaml

# Use debug container to troubleshoot
kubectl debug minimal-app -it --image=ubuntu --target=app

# Inside the debug container, you can:
# 1. Install debugging tools
# apt update && apt install -y htop strace tcpdump curl

# 2. Inspect the target container's processes
# ps aux

# 3. Check network connectivity
# netstat -tulpn

# 4. Analyze file system
# df -h
# ls -la /proc/1/root/
```

### Expected Outcomes
- Ability to diagnose and fix container startup issues
- Skills in debugging network connectivity problems
- Understanding of storage troubleshooting techniques
- Proficiency with performance debugging tools
- Experience using debug containers for advanced troubleshooting

### Validation
1. Successfully identify and fix the problematic deployment
2. Resolve network connectivity issues
3. Debug and fix storage problems
4. Use profiling tools to identify performance bottlenecks
5. Demonstrate debug container usage

---

## Exercise 4: Distributed Tracing Implementation

### Objective
Implement distributed tracing for a microservices application using Jaeger.

### Tasks

#### Task 4.1: Deploy Jaeger
Set up Jaeger for distributed tracing.

```bash
# Deploy Jaeger All-in-One
cat > jaeger.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jaeger
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jaeger
  template:
    metadata:
      labels:
        app: jaeger
    spec:
      containers:
      - name: jaeger
        image: jaegertracing/all-in-one:latest
        ports:
        - containerPort: 16686  # Jaeger UI
        - containerPort: 14268  # jaeger.thrift
        - containerPort: 6831   # jaeger.thrift compact
        - containerPort: 6832   # jaeger.thrift binary
        env:
        - name: COLLECTOR_ZIPKIN_HTTP_PORT
          value: "9411"
---
apiVersion: v1
kind: Service
metadata:
  name: jaeger
  namespace: monitoring
spec:
  selector:
    app: jaeger
  ports:
  - name: ui
    port: 16686
    targetPort: 16686
  - name: thrift
    port: 14268
    targetPort: 14268
  - name: compact
    port: 6831
    targetPort: 6831
    protocol: UDP
  - name: binary
    port: 6832
    targetPort: 6832
    protocol: UDP
  type: NodePort
EOF

kubectl apply -f jaeger.yaml
```

#### Task 4.2: Create Instrumented Microservices
Build microservices with tracing instrumentation.

```python
# Create frontend-service.py
from flask import Flask, jsonify, request
import requests
import time
import random
from jaeger_client import Config
from flask_opentracing import FlaskTracing

app = Flask(__name__)

# Configure Jaeger
config = Config(
    config={
        'sampler': {'type': 'const', 'param': 1},
        'logging': True,
        'reporter_batch_size': 1,
    },
    service_name='frontend-service',
    validate=True,
)
jaeger_tracer = config.initialize_tracer()
tracing = FlaskTracing(jaeger_tracer, True, app)

@app.route('/')
def home():
    with jaeger_tracer.start_span('frontend-home') as span:
        span.set_tag('component', 'frontend')
        span.log_kv({'event': 'home_request'})
        
        # Call backend service
        try:
            response = requests.get('http://backend-service:8080/api/data', timeout=5)
            data = response.json()
            span.set_tag('backend_response', 'success')
        except Exception as e:
            span.set_tag('backend_response', 'error')
            span.log_kv({'event': 'backend_error', 'error': str(e)})
            data = {'error': 'Backend unavailable'}
        
        return jsonify({
            'service': 'frontend',
            'backend_data': data,
            'timestamp': time.time()
        })

@app.route('/health')
def health():
    return jsonify({'status': 'healthy'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```

```python
# Create backend-service.py
from flask import Flask, jsonify
import time
import random
from jaeger_client import Config
from flask_opentracing import FlaskTracing

app = Flask(__name__)

# Configure Jaeger
config = Config(
    config={
        'sampler': {'type': 'const', 'param': 1},
        'logging': True,
        'reporter_batch_size': 1,
    },
    service_name='backend-service',
    validate=True,
)
jaeger_tracer = config.initialize_tracer()
tracing = FlaskTracing(jaeger_tracer, True, app)

@app.route('/api/data')
def get_data():
    with jaeger_tracer.start_span('backend-get-data') as span:
        span.set_tag('component', 'backend')
        
        # Simulate database call
        with jaeger_tracer.start_span('database-query', child_of=span) as db_span:
            db_span.set_tag('db.type', 'postgresql')
            db_span.set_tag('db.statement', 'SELECT * FROM users')
            
            # Simulate query time
            query_time = random.uniform(0.1, 0.5)
            time.sleep(query_time)
            db_span.set_tag('db.duration', query_time)
        
        # Simulate business logic
        with jaeger_tracer.start_span('business-logic', child_of=span) as logic_span:
            logic_span.set_tag('operation', 'data_processing')
            time.sleep(random.uniform(0.05, 0.2))
            
            # Occasionally simulate errors
            if random.random() < 0.1:  # 10% error rate
                logic_span.set_tag('error', True)
                logic_span.log_kv({'event': 'error', 'message': 'Processing failed'})
                return jsonify({'error': 'Processing failed'}), 500
        
        return jsonify({
            'data': ['item1', 'item2', 'item3'],
            'timestamp': time.time(),
            'query_time': query_time
        })

@app.route('/health')
def health():
    return jsonify({'status': 'healthy'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
```

#### Task 4.3: Deploy Traced Services
Deploy the instrumented services with tracing configuration.

```yaml
# Create traced-services.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-service
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend-service
  template:
    metadata:
      labels:
        app: frontend-service
    spec:
      containers:
      - name: frontend
        image: your-registry/frontend-service:latest
        ports:
        - containerPort: 5000
        env:
        - name: JAEGER_AGENT_HOST
          value: "jaeger.monitoring.svc.cluster.local"
        - name: JAEGER_AGENT_PORT
          value: "6831"
---
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
spec:
  selector:
    app: frontend-service
  ports:
  - port: 5000
    targetPort: 5000
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-service
spec:
  replicas: 3
  selector:
    matchLabels:
      app: backend-service
  template:
    metadata:
      labels:
        app: backend-service
    spec:
      containers:
      - name: backend
        image: your-registry/backend-service:latest
        ports:
        - containerPort: 8080
        env:
        - name: JAEGER_AGENT_HOST
          value: "jaeger.monitoring.svc.cluster.local"
        - name: JAEGER_AGENT_PORT
          value: "6831"
---
apiVersion: v1
kind: Service
metadata:
  name: backend-service
spec:
  selector:
    app: backend-service
  ports:
  - port: 8080
    targetPort: 8080
```

#### Task 4.4: Analyze Traces
Generate load and analyze distributed traces.

```python
# Create trace-generator.py
import requests
import time
import threading
import random

def generate_requests(frontend_url, duration=300):
    """Generate requests to create traces"""
    end_time = time.time() + duration
    
    while time.time() < end_time:
        try:
            response = requests.get(frontend_url, timeout=10)
            print(f"Request: {response.status_code} - {response.elapsed.total_seconds():.3f}s")
        except Exception as e:
            print(f"Error: {e}")
        
        # Vary request rate
        time.sleep(random.uniform(0.5, 2.0))

if __name__ == "__main__":
    frontend_url = "http://frontend-service:5000/"
    
    # Start multiple threads to generate concurrent requests
    threads = []
    for i in range(3):
        t = threading.Thread(target=generate_requests, args=(frontend_url, 600))
        t.start()
        threads.append(t)
    
    for t in threads:
        t.join()
```

### Expected Outcomes
- Functional distributed tracing with Jaeger
- Instrumented microservices generating traces
- Ability to analyze request flows across services
- Understanding of trace analysis for performance optimization

### Validation
1. Access Jaeger UI and view traces
2. Identify slow operations in trace timeline
3. Analyze error traces and root causes
4. Correlate traces with metrics and logs

---

## Exercise 5: Comprehensive Performance Testing

### Objective
Conduct comprehensive performance testing for containerized applications using multiple tools and strategies.

### Tasks

#### Task 5.1: Set Up Load Testing Environment
Prepare a comprehensive load testing environment.

```bash
# Deploy test target application
cat > performance-target.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: performance-target
spec:
  replicas: 3
  selector:
    matchLabels:
      app: performance-target
  template:
    metadata:
      labels:
        app: performance-target
    spec:
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "500m"
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 30
---
apiVersion: v1
kind: Service
metadata:
  name: performance-target
spec:
  selector:
    app: performance-target
  ports:
  - port: 80
    targetPort: 80
  type: LoadBalancer
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: performance-target-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: performance-target
  minReplicas: 3
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
EOF

kubectl apply -f performance-target.yaml
```

#### Task 5.2: Apache Bench Testing
Conduct load testing using Apache Bench.

```bash
# Basic load test
ab -n 10000 -c 50 http://performance-target/

# Sustained load test
ab -n 50000 -c 100 -t 300 http://performance-target/

# Test with different concurrency levels
for concurrency in 10 25 50 100 200; do
    echo "Testing with concurrency: $concurrency"
    ab -n 5000 -c $concurrency http://performance-target/ > ab_results_${concurrency}.txt
done

# Analyze results
grep "Requests per second" ab_results_*.txt
grep "Time per request" ab_results_*.txt
```

#### Task 5.3: k6 Load Testing
Implement comprehensive load testing with k6.

```javascript
// Create k6-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

const errorRate = new Rate('errors');

export let options = {
  stages: [
    { duration: '2m', target: 10 },   // Ramp up
    { duration: '5m', target: 10 },   // Stay at 10 users
    { duration: '2m', target: 50 },   // Ramp up to 50 users
    { duration: '5m', target: 50 },   // Stay at 50 users
    { duration: '2m', target: 100 },  // Ramp up to 100 users
    { duration: '5m', target: 100 },  // Stay at 100 users
    { duration: '5m', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% of requests should be below 500ms
    http_req_failed: ['rate<0.1'],    // Error rate should be less than 10%
    errors: ['rate<0.1'],             // Custom error rate
  },
};

export default function() {
  const response = http.get('http://performance-target/');
  
  const result = check(response, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
  });
  
  errorRate.add(!result);
  
  sleep(1);
}

// Spike test
export let spikeOptions = {
  stages: [
    { duration: '10s', target: 10 },
    { duration: '1m', target: 10 },
    { duration: '10s', target: 100 }, // Spike to 100 users
    { duration: '3m', target: 100 },
    { duration: '10s', target: 10 },
    { duration: '3m', target: 10 },
    { duration: '10s', target: 0 },
  ],
};
```

#### Task 5.4: JMeter Testing
Create comprehensive JMeter test plans.

```xml
<!-- Create jmeter-test-plan.jmx -->
<?xml version="1.0" encoding="UTF-8"?>
<jmeterTestPlan version="1.2">
  <hashTree>
    <TestPlan guiclass="TestPlanGui" testclass="TestPlan" testname="Performance Test">
      <stringProp name="TestPlan.comments">Comprehensive performance test</stringProp>
      <boolProp name="TestPlan.functional_mode">false</boolProp>
      <boolProp name="TestPlan.serialize_threadgroups">false</boolProp>
      <elementProp name="TestPlan.arguments" elementType="Arguments" guiclass="ArgumentsPanel" testclass="Arguments" testname="User Defined Variables">
        <collectionProp name="Arguments.arguments"/>
      </elementProp>
      <stringProp name="TestPlan.user_define_classpath"></stringProp>
    </TestPlan>
    <hashTree>
      <ThreadGroup guiclass="ThreadGroupGui" testclass="ThreadGroup" testname="Load Test">
        <stringProp name="ThreadGroup.on_sample_error">continue</stringProp>
        <elementProp name="ThreadGroup.main_controller" elementType="LoopController" guiclass="LoopControllerGui" testclass="LoopController" testname="Loop Controller">
          <boolProp name="LoopController.continue_forever">false</boolProp>
          <stringProp name="LoopController.loops">10</stringProp>
        </elementProp>
        <stringProp name="ThreadGroup.num_threads">50</stringProp>
        <stringProp name="ThreadGroup.ramp_time">300</stringProp>
        <longProp name="ThreadGroup.start_time">1</longProp>
        <longProp name="ThreadGroup.end_time">1</longProp>
        <boolProp name="ThreadGroup.scheduler">false</boolProp>
        <stringProp name="ThreadGroup.duration"></stringProp>
        <stringProp name="ThreadGroup.delay"></stringProp>
      </ThreadGroup>
      <hashTree>
        <HTTPSamplerProxy guiclass="HttpTestSampleGui" testclass="HTTPSamplerProxy" testname="HTTP Request">
          <elementProp name="HTTPsampler.Arguments" elementType="Arguments" guiclass="HTTPArgumentsPanel" testclass="Arguments" testname="User Defined Variables">
            <collectionProp name="Arguments.arguments"/>
          </elementProp>
          <stringProp name="HTTPSampler.domain">performance-target</stringProp>
          <stringProp name="HTTPSampler.port">80</stringProp>
          <stringProp name="HTTPSampler.protocol">http</stringProp>
          <stringProp name="HTTPSampler.contentEncoding"></stringProp>
          <stringProp name="HTTPSampler.path">/</stringProp>
          <stringProp name="HTTPSampler.method">GET</stringProp>
          <boolProp name="HTTPSampler.follow_redirects">true</boolProp>
          <boolProp name="HTTPSampler.auto_redirects">false</boolProp>
          <boolProp name="HTTPSampler.use_keepalive">true</boolProp>
          <boolProp name="HTTPSampler.DO_MULTIPART_POST">false</boolProp>
          <stringProp name="HTTPSampler.embedded_url_re"></stringProp>
          <stringProp name="HTTPSampler.connect_timeout"></stringProp>
          <stringProp name="HTTPSampler.response_timeout"></stringProp>
        </HTTPSamplerProxy>
      </hashTree>
    </hashTree>
  </hashTree>
</jmeterTestPlan>
```

#### Task 5.5: Chaos Engineering
Implement chaos engineering to test system resilience.

```yaml
# Install Chaos Mesh or Litmus
# For this exercise, we'll use simple chaos scenarios

# Create pod-killer.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: chaos-pod-killer
spec:
  template:
    spec:
      containers:
      - name: chaos
        image: bitnami/kubectl
        command: ["/bin/sh"]
        args:
        - -c
        - |
          while true; do
            # Get random pod
            POD=$(kubectl get pods -l app=performance-target -o jsonpath='{.items[0].metadata.name}')
            echo "Killing pod: $POD"
            kubectl delete pod $POD
            sleep 60
          done
      restartPolicy: Never
  backoffLimit: 0

# Create network-chaos.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: network-chaos
spec:
  replicas: 1
  selector:
    matchLabels:
      app: network-chaos
  template:
    metadata:
      labels:
        app: network-chaos
    spec:
      containers:
      - name: chaos
        image: nicolaka/netshoot
        command: ["/bin/sh"]
        args:
        - -c
        - |
          while true; do
            # Simulate network latency
            tc qdisc add dev eth0 root netem delay 100ms
            sleep 30
            tc qdisc del dev eth0 root
            sleep 30
          done
        securityContext:
          capabilities:
            add: ["NET_ADMIN"]
```

#### Task 5.6: Performance Analysis and Optimization
Analyze results and optimize performance.

```bash
# Collect performance metrics during tests
echo "Collecting baseline metrics..."
kubectl top pods -l app=performance-target
kubectl top nodes

# Run performance test and collect metrics
echo "Running load test with monitoring..."
kubectl get hpa performance-target-hpa --watch &
HPA_PID=$!

# Run your preferred load test here
k6 run k6-test.js

# Stop monitoring
kill $HPA_PID

# Analyze results
echo "Performance test analysis:"
kubectl describe hpa performance-target-hpa
kubectl get events --sort-by='.lastTimestamp' | grep performance-target

# Check scaling behavior
kubectl get pods -l app=performance-target
kubectl top pods -l app=performance-target

# Generate performance report
cat > performance-report.md << 'EOF'
# Performance Test Report

## Test Configuration
- Target: performance-target service
- Initial replicas: 3
- Max replicas: 20
- CPU target: 70%

## Test Results
### Load Test Results
- Tool: k6/ab/JMeter
- Duration: X minutes
- Peak RPS: X requests/second
- Average response time: X ms
- 95th percentile: X ms
- Error rate: X%

### Scaling Behavior
- Time to scale out: X seconds
- Time to scale in: X seconds
- Maximum pods reached: X
- CPU utilization: X%

### Resource Usage
- Average CPU: X%
- Average Memory: X MB
- Peak CPU: X%
- Peak Memory: X MB

## Recommendations
1. [List optimization recommendations]
2. [Resource tuning suggestions]
3. [Scaling improvements]
EOF
```

### Expected Outcomes
- Comprehensive performance testing methodology
- Understanding of different load testing tools
- Experience with chaos engineering
- Performance optimization skills
- Ability to generate performance reports

### Validation
1. Successfully conduct load tests with multiple tools
2. Observe autoscaling behavior under load
3. Implement chaos engineering scenarios
4. Generate comprehensive performance reports
5. Identify and implement performance optimizations

---

## Final Project: Enterprise Performance and Troubleshooting Solution

### Objective
Design and implement a comprehensive performance monitoring and troubleshooting solution for an enterprise microservices application.

### Project Requirements

#### Application Architecture
Create a microservices application with the following components:
- Frontend service (React/Angular)
- API Gateway
- User service
- Product service
- Order service
- Payment service
- Notification service
- Database (PostgreSQL)
- Cache (Redis)
- Message queue (RabbitMQ)

#### Performance Monitoring Stack
Implement comprehensive monitoring with:
- Prometheus for metrics collection
- Grafana for visualization
- Jaeger for distributed tracing
- ELK/EFK stack for log aggregation
- Alert Manager for alerting

#### Performance Testing Suite
Create performance tests for:
- Load testing (k6, JMeter)
- Stress testing
- Spike testing
- Endurance testing
- Chaos engineering

#### Troubleshooting Documentation
Develop troubleshooting runbooks for:
- Container startup issues
- Network connectivity problems
- Storage performance issues
- Memory leaks and CPU spikes
- Database connection issues
- Service discovery problems

### Implementation Steps

1. **Design Architecture**
   - Create architecture diagrams
   - Define service interfaces
   - Plan resource allocation
   - Design monitoring strategy

2. **Deploy Infrastructure**
   - Set up Kubernetes cluster
   - Deploy monitoring stack
   - Configure networking
   - Set up storage

3. **Implement Services**
   - Build microservices with tracing
   - Add health checks and metrics
   - Configure logging
   - Implement circuit breakers

4. **Performance Testing**
   - Create test scenarios
   - Implement automated testing
   - Set up continuous testing
   - Document results

5. **Monitoring and Alerting**
   - Configure dashboards
   - Set up alert rules
   - Create escalation procedures
   - Test alert notifications

6. **Documentation**
   - Create operational runbooks
   - Document troubleshooting procedures
   - Write performance tuning guides
   - Create training materials

### Deliverables

1. **Source Code**
   - Microservices applications
   - Kubernetes manifests
   - Monitoring configurations
   - Performance test scripts

2. **Documentation**
   - Architecture documentation
   - Deployment guides
   - Troubleshooting runbooks
   - Performance tuning guides

3. **Dashboards and Alerts**
   - Grafana dashboards
   - Prometheus alert rules
   - Jaeger tracing setup
   - Log aggregation configuration

4. **Performance Reports**
   - Baseline performance metrics
   - Load testing results
   - Optimization recommendations
   - Capacity planning guidelines

### Evaluation Criteria

- **Architecture Design** (20%)
  - Proper microservices design
  - Scalable infrastructure
  - Monitoring strategy
  - Security considerations

- **Implementation Quality** (30%)
  - Code quality and documentation
  - Proper instrumentation
  - Error handling
  - Performance optimization

- **Monitoring and Observability** (25%)
  - Comprehensive metrics
  - Effective dashboards
  - Proper alerting
  - Distributed tracing

- **Performance Testing** (15%)
  - Test coverage
  - Realistic scenarios
  - Automation
  - Results analysis

- **Troubleshooting Documentation** (10%)
  - Comprehensive runbooks
  - Clear procedures
  - Practical examples
  - Training materials

### Success Metrics

- All services deployed and functional
- Monitoring stack collecting metrics
- Performance tests passing SLA requirements
- Alert rules triggering appropriately
- Documentation complete and accurate
- Troubleshooting procedures validated

---

## Additional Resources

### Tools and Documentation
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Best Practices](https://grafana.com/docs/grafana/latest/best-practices/)
- [Jaeger Documentation](https://www.jaegertracing.io/docs/)
- [k6 Load Testing](https://k6.io/docs/)
- [Kubernetes Debugging](https://kubernetes.io/docs/tasks/debug-application-cluster/)

### Performance Optimization Guides
- [Container Performance Tuning](https://docs.docker.com/config/containers/resource_constraints/)
- [Kubernetes Performance Tuning](https://kubernetes.io/docs/concepts/cluster-administration/system-metrics/)
- [JVM Performance Tuning](https://docs.oracle.com/javase/8/docs/technotes/guides/vm/performance-enhancements-7.html)

### Troubleshooting References
- [Docker Troubleshooting](https://docs.docker.com/config/troubleshooting/)
- [Kubernetes Troubleshooting](https://kubernetes.io/docs/tasks/debug-application-cluster/troubleshooting/)
- [Application Performance Monitoring](https://newrelic.com/resources/ebooks/application-performance-monitoring-guide)

---

## Next Steps

After completing this module:

1. **Practice Regularly**: Set up monitoring in your development environment
2. **Automate Testing**: Integrate performance testing into your CI/CD pipeline
3. **Create Baselines**: Establish performance baselines for your applications
4. **Build Runbooks**: Document common issues and their solutions
5. **Stay Updated**: Keep up with new monitoring and troubleshooting tools
6. **Proceed to Module 10**: Enterprise Architecture Patterns

Remember: Performance monitoring and troubleshooting are ongoing processes that require continuous improvement and adaptation to new challenges and technologies.