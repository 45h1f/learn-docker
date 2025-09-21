# Module 8: Kubernetes Integration - Exercises

## 🎯 Learning Objectives
By completing these exercises, you will:
- Master the migration from Docker Compose to Kubernetes
- Implement advanced deployment patterns and scaling strategies
- Configure persistent storage and StatefulSets
- Set up monitoring, security, and networking in Kubernetes
- Build enterprise-grade container orchestration systems

---

## Exercise 1: Docker Compose to Kubernetes Migration

### 1.1 Multi-Service Application Migration

**Objective**: Migrate a complete multi-service Docker Compose application to Kubernetes.

**Scenario**: You have an e-commerce application with the following services:
- Frontend (React app)
- Backend API (Node.js)
- Database (PostgreSQL)
- Cache (Redis)
- Message Queue (RabbitMQ)

**Steps**:

1. **Analyze the existing Docker Compose setup**:

Create `docker-compose.yml`:
```yaml
version: '3.8'
services:
  frontend:
    build: ./frontend
    ports:
      - "3000:3000"
    environment:
      - REACT_APP_API_URL=http://backend:8080
    depends_on:
      - backend

  backend:
    build: ./backend
    ports:
      - "8080:8080"
    environment:
      - DATABASE_URL=postgresql://user:password@postgres:5432/ecommerce
      - REDIS_URL=redis://redis:6379
      - RABBITMQ_URL=amqp://guest:guest@rabbitmq:5672
    depends_on:
      - postgres
      - redis
      - rabbitmq

  postgres:
    image: postgres:14
    environment:
      POSTGRES_DB: ecommerce
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data
    ports:
      - "6379:6379"

  rabbitmq:
    image: rabbitmq:3-management
    environment:
      RABBITMQ_DEFAULT_USER: guest
      RABBITMQ_DEFAULT_PASS: guest
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq
    ports:
      - "5672:5672"
      - "15672:15672"

  nginx:
    image: nginx:alpine
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
    ports:
      - "80:80"
    depends_on:
      - frontend
      - backend

volumes:
  postgres_data:
  redis_data:
  rabbitmq_data:
```

2. **Create Kubernetes manifests**:

Create namespace:
```yaml
# namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ecommerce
  labels:
    name: ecommerce
```

Create secrets:
```yaml
# secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: database-secret
  namespace: ecommerce
type: Opaque
data:
  postgres-user: dXNlcg==      # base64: user
  postgres-password: cGFzc3dvcmQ=  # base64: password
  postgres-db: ZWNvbW1lcmNl    # base64: ecommerce
---
apiVersion: v1
kind: Secret
metadata:
  name: rabbitmq-secret
  namespace: ecommerce
type: Opaque
data:
  rabbitmq-user: Z3Vlc3Q=      # base64: guest
  rabbitmq-password: Z3Vlc3Q=  # base64: guest
```

Create ConfigMaps:
```yaml
# configmaps.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: ecommerce
data:
  redis_host: "redis-service"
  redis_port: "6379"
  rabbitmq_host: "rabbitmq-service"
  rabbitmq_port: "5672"
  database_host: "postgres-service"
  database_port: "5432"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
  namespace: ecommerce
data:
  nginx.conf: |
    events {
        worker_connections 1024;
    }
    http {
        upstream frontend {
            server frontend-service:3000;
        }
        upstream backend {
            server backend-service:8080;
        }
        server {
            listen 80;
            location / {
                proxy_pass http://frontend;
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
            }
            location /api {
                proxy_pass http://backend;
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
            }
        }
    }
```

3. **Deploy data layer services**:

PostgreSQL deployment:
```yaml
# postgres-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres-deployment
  namespace: ecommerce
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:14
        env:
        - name: POSTGRES_DB
          valueFrom:
            secretKeyRef:
              name: database-secret
              key: postgres-db
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: database-secret
              key: postgres-user
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: database-secret
              key: postgres-password
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
        readinessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - pg_isready -U $POSTGRES_USER -d $POSTGRES_DB
          initialDelaySeconds: 15
          periodSeconds: 5
        livenessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - pg_isready -U $POSTGRES_USER -d $POSTGRES_DB
          initialDelaySeconds: 45
          periodSeconds: 10
      volumes:
      - name: postgres-storage
        persistentVolumeClaim:
          claimName: postgres-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: postgres-service
  namespace: ecommerce
spec:
  selector:
    app: postgres
  ports:
  - protocol: TCP
    port: 5432
    targetPort: 5432
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: ecommerce
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

4. **Deploy application services**:

Backend deployment:
```yaml
# backend-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-deployment
  namespace: ecommerce
spec:
  replicas: 3
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
        image: your-registry/ecommerce-backend:latest
        ports:
        - containerPort: 8080
        env:
        - name: DATABASE_URL
          value: "postgresql://$(DB_USER):$(DB_PASS)@$(DB_HOST):$(DB_PORT)/$(DB_NAME)"
        - name: DB_HOST
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: database_host
        - name: DB_PORT
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: database_port
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: database-secret
              key: postgres-user
        - name: DB_PASS
          valueFrom:
            secretKeyRef:
              name: database-secret
              key: postgres-password
        - name: DB_NAME
          valueFrom:
            secretKeyRef:
              name: database-secret
              key: postgres-db
        - name: REDIS_URL
          value: "redis://$(REDIS_HOST):$(REDIS_PORT)"
        - name: REDIS_HOST
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: redis_host
        - name: REDIS_PORT
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: redis_port
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: backend-service
  namespace: ecommerce
spec:
  selector:
    app: backend
  ports:
  - protocol: TCP
    port: 8080
    targetPort: 8080
```

**Validation**:
- Deploy all components and verify connectivity
- Test data persistence across pod restarts
- Verify service discovery between components
- Check resource utilization and scaling

### 1.2 Advanced Configuration Management

**Objective**: Implement advanced configuration management patterns.

**Steps**:

1. **Create environment-specific configurations**:

Base configuration:
```yaml
# base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- namespace.yaml
- postgres-deployment.yaml
- backend-deployment.yaml
- frontend-deployment.yaml

commonLabels:
  app: ecommerce
  version: v1.0.0
```

Development overlay:
```yaml
# overlays/development/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
- ../../base

namePrefix: dev-

replicas:
- name: backend-deployment
  count: 1
- name: frontend-deployment
  count: 1

patchesStrategicMerge:
- development-config.yaml

images:
- name: ecommerce-backend
  newTag: dev-latest
- name: ecommerce-frontend
  newTag: dev-latest
```

Production overlay:
```yaml
# overlays/production/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
- ../../base

namePrefix: prod-

replicas:
- name: backend-deployment
  count: 5
- name: frontend-deployment
  count: 3

resources:
- hpa.yaml
- network-policy.yaml
- pod-disruption-budget.yaml

patchesStrategicMerge:
- production-config.yaml

images:
- name: ecommerce-backend
  newTag: v1.2.3
- name: ecommerce-frontend
  newTag: v1.2.3
```

**Validation**:
- Deploy to different environments using Kustomize
- Verify environment-specific configurations
- Test configuration hot-reloading

---

## Exercise 2: Advanced Deployment Patterns

### 2.1 Blue-Green Deployment Implementation

**Objective**: Implement blue-green deployment for zero-downtime updates.

**Steps**:

1. **Create blue-green deployment manifests**:

```yaml
# blue-green-deployment.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: ecommerce-backend-rollout
  namespace: ecommerce
spec:
  replicas: 5
  strategy:
    blueGreen:
      activeService: backend-active-service
      previewService: backend-preview-service
      autoPromotionEnabled: false
      scaleDownDelaySeconds: 30
      prePromotionAnalysis:
        templates:
        - templateName: success-rate
        args:
        - name: service-name
          value: backend-preview-service
      postPromotionAnalysis:
        templates:
        - templateName: success-rate
        args:
        - name: service-name
          value: backend-active-service
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
        image: ecommerce-backend:stable
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: backend-active-service
  namespace: ecommerce
spec:
  selector:
    app: backend
  ports:
  - protocol: TCP
    port: 8080
    targetPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: backend-preview-service
  namespace: ecommerce
spec:
  selector:
    app: backend
  ports:
  - protocol: TCP
    port: 8080
    targetPort: 8080
```

2. **Create analysis templates**:

```yaml
# analysis-template.yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
  namespace: ecommerce
spec:
  args:
  - name: service-name
  metrics:
  - name: success-rate
    interval: 10s
    count: 5
    successCondition: result[0] >= 0.95
    provider:
      prometheus:
        address: http://prometheus.monitoring.svc.cluster.local:9090
        query: |
          sum(rate(http_requests_total{service="{{args.service-name}}",status!~"5.."}[2m])) /
          sum(rate(http_requests_total{service="{{args.service-name}}"}[2m]))
  - name: latency
    interval: 10s
    count: 5
    successCondition: result[0] <= 0.5
    provider:
      prometheus:
        address: http://prometheus.monitoring.svc.cluster.local:9090
        query: |
          histogram_quantile(0.95,
            sum(rate(http_request_duration_seconds_bucket{service="{{args.service-name}}"}[2m])) by (le)
          )
```

**Validation**:
- Perform blue-green deployment
- Verify traffic switching
- Test rollback procedures
- Monitor application metrics during deployment

### 2.2 Canary Deployment with Traffic Splitting

**Objective**: Implement gradual traffic shifting for safe deployments.

**Steps**:

1. **Set up Istio service mesh**:

```bash
# Install Istio
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH
istioctl install --set values.defaultRevision=default -y

# Enable sidecar injection
kubectl label namespace ecommerce istio-injection=enabled
```

2. **Create canary deployment with Argo Rollouts**:

```yaml
# canary-rollout.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: backend-canary
  namespace: ecommerce
spec:
  replicas: 10
  strategy:
    canary:
      canaryService: backend-canary-service
      stableService: backend-stable-service
      trafficRouting:
        istio:
          virtualService:
            name: backend-virtualservice
          destinationRule:
            name: backend-destinationrule
            canarySubsetName: canary
            stableSubsetName: stable
      steps:
      - setWeight: 5
      - pause: {duration: 1m}
      - setWeight: 10
      - pause: {duration: 2m}
      - setWeight: 25
      - pause: {duration: 5m}
      - setWeight: 50
      - pause: {duration: 10m}
      - setWeight: 75
      - pause: {duration: 10m}
      analysis:
        templates:
        - templateName: success-rate
        args:
        - name: service-name
          value: backend-canary-service
        startingStep: 2
        interval: 30s
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
        image: ecommerce-backend:latest
        ports:
        - containerPort: 8080
```

3. **Create Istio traffic management**:

```yaml
# istio-traffic.yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: backend-virtualservice
  namespace: ecommerce
spec:
  hosts:
  - backend-service
  http:
  - route:
    - destination:
        host: backend-service
        subset: stable
      weight: 100
    - destination:
        host: backend-service
        subset: canary
      weight: 0
---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: backend-destinationrule
  namespace: ecommerce
spec:
  host: backend-service
  subsets:
  - name: stable
    labels:
      app: backend
  - name: canary
    labels:
      app: backend
```

**Validation**:
- Deploy canary version
- Monitor traffic distribution
- Verify automated analysis and promotion
- Test failure scenarios and rollback

---

## Exercise 3: Scaling and Performance

### 3.1 Horizontal Pod Autoscaler (HPA) Configuration

**Objective**: Configure advanced autoscaling based on multiple metrics.

**Steps**:

1. **Install metrics server**:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

2. **Create custom metrics with Prometheus**:

```yaml
# custom-metrics.yaml
apiVersion: v1
kind: ServiceMonitor
metadata:
  name: backend-metrics
  namespace: ecommerce
spec:
  selector:
    matchLabels:
      app: backend
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
---
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: backend-rules
  namespace: ecommerce
spec:
  groups:
  - name: backend.rules
    rules:
    - record: backend:requests_per_second
      expr: sum(rate(http_requests_total{app="backend"}[1m]))
    - record: backend:average_response_time
      expr: avg(http_request_duration_seconds{app="backend"})
```

3. **Configure HPA with multiple metrics**:

```yaml
# advanced-hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: backend-hpa
  namespace: ecommerce
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: backend-deployment
  minReplicas: 3
  maxReplicas: 50
  metrics:
  # CPU utilization
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  # Memory utilization
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  # Custom metric: requests per second
  - type: Pods
    pods:
      metric:
        name: requests_per_second
      target:
        type: AverageValue
        averageValue: "100"
  # External metric: queue length
  - type: External
    external:
      metric:
        name: rabbitmq_queue_messages
        selector:
          matchLabels:
            queue: "processing"
      target:
        type: AverageValue
        averageValue: "10"
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
      - type: Pods
        value: 2
        periodSeconds: 60
      selectPolicy: Min
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 60
      - type: Pods
        value: 4
        periodSeconds: 60
      selectPolicy: Max
```

4. **Create Vertical Pod Autoscaler (VPA)**:

```yaml
# vpa.yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: backend-vpa
  namespace: ecommerce
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: backend-deployment
  updatePolicy:
    updateMode: "Auto"
  resourcePolicy:
    containerPolicies:
    - containerName: backend
      minAllowed:
        cpu: 100m
        memory: 128Mi
      maxAllowed:
        cpu: 2
        memory: 4Gi
      controlledResources: ["cpu", "memory"]
      controlledValues: RequestsAndLimits
```

**Validation**:
- Generate load and observe scaling behavior
- Monitor resource utilization during scaling events
- Test different scaling policies
- Verify VPA recommendations and updates

### 3.2 Cluster Autoscaler Configuration

**Objective**: Configure cluster-level autoscaling for node management.

**Steps**:

1. **Configure cluster autoscaler**:

```yaml
# cluster-autoscaler.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cluster-autoscaler
  namespace: kube-system
  labels:
    app: cluster-autoscaler
spec:
  selector:
    matchLabels:
      app: cluster-autoscaler
  template:
    metadata:
      labels:
        app: cluster-autoscaler
    spec:
      serviceAccountName: cluster-autoscaler
      containers:
      - image: k8s.gcr.io/autoscaling/cluster-autoscaler:v1.21.0
        name: cluster-autoscaler
        resources:
          limits:
            cpu: 100m
            memory: 300Mi
          requests:
            cpu: 100m
            memory: 300Mi
        command:
        - ./cluster-autoscaler
        - --v=4
        - --stderrthreshold=info
        - --cloud-provider=aws
        - --skip-nodes-with-local-storage=false
        - --expander=least-waste
        - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/ecommerce
        - --balance-similar-node-groups
        - --skip-nodes-with-system-pods=false
        env:
        - name: AWS_REGION
          value: us-west-2
```

**Validation**:
- Create resource pressure to trigger node scaling
- Monitor cluster autoscaler logs
- Verify node addition and removal
- Test cost optimization features

---

## Exercise 4: StatefulSets and Persistent Storage

### 4.1 Database Cluster with StatefulSets

**Objective**: Deploy a highly available PostgreSQL cluster using StatefulSets.

**Steps**:

1. **Create storage classes**:

```yaml
# storage-classes.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
  encrypted: "true"
allowVolumeExpansion: true
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: backup-storage
provisioner: kubernetes.io/aws-ebs
parameters:
  type: sc1
  encrypted: "true"
allowVolumeExpansion: true
reclaimPolicy: Retain
volumeBindingMode: Immediate
```

2. **Deploy PostgreSQL StatefulSet with replication**:

```yaml
# postgres-cluster.yaml
apiVersion: v1
kind: Secret
metadata:
  name: postgres-cluster-secret
  namespace: ecommerce
type: Opaque
data:
  postgres-password: c3VwZXJzZWNyZXQ=  # base64: supersecret
  replication-password: cmVwbGljYXRvcg==  # base64: replicator
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-config
  namespace: ecommerce
data:
  postgresql.conf: |
    listen_addresses = '*'
    max_connections = 200
    shared_buffers = 256MB
    effective_cache_size = 1GB
    maintenance_work_mem = 64MB
    checkpoint_completion_target = 0.9
    wal_buffers = 16MB
    default_statistics_target = 100
    random_page_cost = 1.1
    effective_io_concurrency = 200
    work_mem = 4MB
    min_wal_size = 1GB
    max_wal_size = 4GB
    max_worker_processes = 8
    max_parallel_workers_per_gather = 4
    max_parallel_workers = 8
    max_parallel_maintenance_workers = 4
    
    # Replication settings
    wal_level = replica
    max_wal_senders = 10
    max_replication_slots = 10
    hot_standby = on
    hot_standby_feedback = on
    
  pg_hba.conf: |
    local all all trust
    host all all 127.0.0.1/32 trust
    host all all ::1/128 trust
    host all all 0.0.0.0/0 md5
    host replication replicator 0.0.0.0/0 md5
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres-cluster
  namespace: ecommerce
spec:
  serviceName: postgres-headless
  replicas: 3
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      initContainers:
      - name: postgres-init
        image: postgres:14
        env:
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-cluster-secret
              key: postgres-password
        - name: REPLICATION_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-cluster-secret
              key: replication-password
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        command:
        - /bin/bash
        - -c
        - |
          if [ "$POD_NAME" = "postgres-cluster-0" ]; then
            echo "Initializing primary database"
            initdb -D /var/lib/postgresql/data/pgdata
          else
            echo "Setting up replica"
            until pg_isready -h postgres-cluster-0.postgres-headless; do
              echo "Waiting for primary to be ready..."
              sleep 2
            done
            pg_basebackup -h postgres-cluster-0.postgres-headless -D /var/lib/postgresql/data/pgdata -U replicator -W
          fi
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
      containers:
      - name: postgres
        image: postgres:14
        env:
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-cluster-secret
              key: postgres-password
        - name: POSTGRES_DB
          value: ecommerce
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
        - name: postgres-config
          mountPath: /etc/postgresql/postgresql.conf
          subPath: postgresql.conf
        - name: postgres-config
          mountPath: /etc/postgresql/pg_hba.conf
          subPath: pg_hba.conf
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        readinessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - pg_isready -U postgres
          initialDelaySeconds: 15
          periodSeconds: 5
        livenessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - pg_isready -U postgres
          initialDelaySeconds: 45
          periodSeconds: 10
      volumes:
      - name: postgres-config
        configMap:
          name: postgres-config
  volumeClaimTemplates:
  - metadata:
      name: postgres-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: "fast-ssd"
      resources:
        requests:
          storage: 20Gi
---
apiVersion: v1
kind: Service
metadata:
  name: postgres-headless
  namespace: ecommerce
spec:
  clusterIP: None
  selector:
    app: postgres
  ports:
  - protocol: TCP
    port: 5432
    targetPort: 5432
---
apiVersion: v1
kind: Service
metadata:
  name: postgres-primary
  namespace: ecommerce
spec:
  selector:
    app: postgres
    statefulset.kubernetes.io/pod-name: postgres-cluster-0
  ports:
  - protocol: TCP
    port: 5432
    targetPort: 5432
---
apiVersion: v1
kind: Service
metadata:
  name: postgres-replica
  namespace: ecommerce
spec:
  selector:
    app: postgres
  ports:
  - protocol: TCP
    port: 5432
    targetPort: 5432
```

**Validation**:
- Verify StatefulSet pod ordering and naming
- Test data persistence across pod restarts
- Validate read/write splitting between primary and replicas
- Test scaling operations

### 4.2 Backup and Disaster Recovery

**Objective**: Implement automated backup and disaster recovery procedures.

**Steps**:

1. **Create backup CronJob**:

```yaml
# backup-cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
  namespace: ecommerce
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 7
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: backup-service-account
          containers:
          - name: postgres-backup
            image: postgres:14
            env:
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgres-cluster-secret
                  key: postgres-password
            - name: AWS_ACCESS_KEY_ID
              valueFrom:
                secretKeyRef:
                  name: aws-credentials
                  key: access-key-id
            - name: AWS_SECRET_ACCESS_KEY
              valueFrom:
                secretKeyRef:
                  name: aws-credentials
                  key: secret-access-key
            command:
            - /bin/bash
            - -c
            - |
              BACKUP_FILE="backup-$(date +%Y%m%d-%H%M%S).sql"
              echo "Creating backup: $BACKUP_FILE"
              
              # Create backup
              pg_dump -h postgres-primary \
                      -U postgres \
                      -d ecommerce \
                      --verbose \
                      --format=custom \
                      --compress=9 > /tmp/$BACKUP_FILE
              
              # Upload to S3
              aws s3 cp /tmp/$BACKUP_FILE s3://ecommerce-backups/postgres/
              
              # Create point-in-time recovery backup
              pg_basebackup -h postgres-primary \
                           -U postgres \
                           -D /tmp/basebackup \
                           -Ft -z -P
              
              tar -czf /tmp/basebackup-$(date +%Y%m%d-%H%M%S).tar.gz -C /tmp basebackup
              aws s3 cp /tmp/basebackup-$(date +%Y%m%d-%H%M%S).tar.gz s3://ecommerce-backups/postgres/basebackup/
              
              # Cleanup old backups (keep last 30 days)
              aws s3 ls s3://ecommerce-backups/postgres/ | \
                while read -r line; do
                  createDate=$(echo $line | awk '{print $1" "$2}')
                  createDate=$(date -d "$createDate" +%s)
                  olderThan=$(date -d "30 days ago" +%s)
                  if [[ $createDate -lt $olderThan ]]; then
                    fileName=$(echo $line | awk '{print $4}')
                    if [[ $fileName != "" ]]; then
                      aws s3 rm s3://ecommerce-backups/postgres/$fileName
                    fi
                  fi
                done
            volumeMounts:
            - name: backup-storage
              mountPath: /backup
          volumes:
          - name: backup-storage
            persistentVolumeClaim:
              claimName: backup-pvc
          restartPolicy: OnFailure
```

2. **Create disaster recovery procedure**:

```yaml
# disaster-recovery.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: disaster-recovery-scripts
  namespace: ecommerce
data:
  restore.sh: |
    #!/bin/bash
    set -e
    
    BACKUP_FILE=$1
    if [ -z "$BACKUP_FILE" ]; then
      echo "Usage: $0 <backup-file>"
      exit 1
    fi
    
    echo "Starting disaster recovery from $BACKUP_FILE"
    
    # Download backup from S3
    aws s3 cp s3://ecommerce-backups/postgres/$BACKUP_FILE /tmp/
    
    # Stop application
    kubectl scale deployment backend-deployment --replicas=0 -n ecommerce
    kubectl scale deployment frontend-deployment --replicas=0 -n ecommerce
    
    # Drop and recreate database
    kubectl exec postgres-cluster-0 -n ecommerce -- psql -U postgres -c "DROP DATABASE IF EXISTS ecommerce;"
    kubectl exec postgres-cluster-0 -n ecommerce -- psql -U postgres -c "CREATE DATABASE ecommerce;"
    
    # Restore backup
    kubectl cp /tmp/$BACKUP_FILE ecommerce/postgres-cluster-0:/tmp/
    kubectl exec postgres-cluster-0 -n ecommerce -- pg_restore -U postgres -d ecommerce /tmp/$BACKUP_FILE
    
    # Restart application
    kubectl scale deployment backend-deployment --replicas=3 -n ecommerce
    kubectl scale deployment frontend-deployment --replicas=2 -n ecommerce
    
    echo "Disaster recovery completed successfully"
  
  test-recovery.sh: |
    #!/bin/bash
    # Test disaster recovery procedure
    
    # Create test namespace
    kubectl create namespace ecommerce-dr-test
    
    # Deploy minimal application for testing
    kubectl apply -f postgres-deployment.yaml -n ecommerce-dr-test
    
    # Run restore procedure
    ./restore.sh latest-backup.sql
    
    # Verify data integrity
    kubectl exec postgres-cluster-0 -n ecommerce-dr-test -- psql -U postgres -d ecommerce -c "SELECT COUNT(*) FROM users;"
    
    # Cleanup
    kubectl delete namespace ecommerce-dr-test
```

**Validation**:
- Run backup procedures and verify backup creation
- Test disaster recovery procedure in isolated environment
- Validate data integrity after recovery
- Measure recovery time objectives (RTO) and recovery point objectives (RPO)

---

## Exercise 5: Service Mesh and Advanced Networking

### 5.1 Istio Service Mesh Implementation

**Objective**: Implement comprehensive service mesh with traffic management, security, and observability.

**Steps**:

1. **Install and configure Istio**:

```bash
# Install Istio
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH

# Install with custom configuration
istioctl install --set values.pilot.env.EXTERNAL_ISTIOD=false -y

# Enable sidecar injection
kubectl label namespace ecommerce istio-injection=enabled

# Install observability addons
kubectl apply -f samples/addons/prometheus.yaml
kubectl apply -f samples/addons/grafana.yaml
kubectl apply -f samples/addons/jaeger.yaml
kubectl apply -f samples/addons/kiali.yaml
```

2. **Configure traffic management**:

```yaml
# traffic-management.yaml
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: ecommerce-gateway
  namespace: ecommerce
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - ecommerce.example.com
    tls:
      httpsRedirect: true
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: ecommerce-credential
    hosts:
    - ecommerce.example.com
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: ecommerce-virtualservice
  namespace: ecommerce
spec:
  hosts:
  - ecommerce.example.com
  gateways:
  - ecommerce-gateway
  http:
  - match:
    - uri:
        prefix: /api/
    route:
    - destination:
        host: backend-service
        port:
          number: 8080
    timeout: 30s
    retries:
      attempts: 3
      perTryTimeout: 10s
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: frontend-service
        port:
          number: 3000
    fault:
      delay:
        percentage:
          value: 0.1
        fixedDelay: 5s
---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: backend-destination
  namespace: ecommerce
spec:
  host: backend-service
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 10
        maxRequestsPerConnection: 2
    loadBalancer:
      simple: LEAST_CONN
    outlierDetection:
      consecutive5xxErrors: 3
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
```

3. **Implement security policies**:

```yaml
# security-policies.yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: ecommerce
spec:
  mtls:
    mode: STRICT
---
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: frontend-authz
  namespace: ecommerce
spec:
  selector:
    matchLabels:
      app: frontend
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/istio-system/sa/istio-ingressgateway-service-account"]
  - to:
    - operation:
        methods: ["GET", "POST"]
---
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: backend-authz
  namespace: ecommerce
spec:
  selector:
    matchLabels:
      app: backend
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/ecommerce/sa/frontend-service-account"]
  - to:
    - operation:
        methods: ["GET", "POST", "PUT", "DELETE"]
        paths: ["/api/*"]
---
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: database-authz
  namespace: ecommerce
spec:
  selector:
    matchLabels:
      app: postgres
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/ecommerce/sa/backend-service-account"]
  - to:
    - operation:
        ports: ["5432"]
```

**Validation**:
- Verify mTLS communication between services
- Test traffic routing and load balancing
- Monitor service mesh metrics in Kiali
- Validate security policies enforcement

### 5.2 Advanced Networking Patterns

**Objective**: Implement multi-cluster networking and advanced traffic patterns.

**Steps**:

1. **Configure multi-cluster service mesh**:

```yaml
# multi-cluster-setup.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: primary-cluster
spec:
  values:
    pilot:
      env:
        EXTERNAL_ISTIOD: true
        MULTI_CLUSTER_ENABLED: true
    istiodRemote:
      enabled: false
  components:
    pilot:
      k8s:
        env:
        - name: CLUSTER_ID
          value: cluster1
        - name: NETWORK_ID
          value: network1
---
apiVersion: v1
kind: Secret
metadata:
  name: cacerts
  namespace: istio-system
data:
  root-cert.pem: # Base64 encoded root certificate
  cert-chain.pem: # Base64 encoded certificate chain
  ca-cert.pem: # Base64 encoded CA certificate
  ca-key.pem: # Base64 encoded CA private key
```

2. **Implement traffic mirroring for testing**:

```yaml
# traffic-mirroring.yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: backend-mirror
  namespace: ecommerce
spec:
  hosts:
  - backend-service
  http:
  - route:
    - destination:
        host: backend-service
        subset: v1
      weight: 100
    mirror:
      host: backend-service
      subset: v2
    mirrorPercentage:
      value: 10
```

**Validation**:
- Test cross-cluster service discovery
- Verify traffic mirroring functionality
- Monitor multi-cluster communication
- Validate certificate management

---

## Exercise 6: Monitoring, Logging, and Observability

### 6.1 Comprehensive Monitoring Stack

**Objective**: Deploy and configure a complete monitoring solution with Prometheus, Grafana, and AlertManager.

**Steps**:

1. **Deploy Prometheus Operator**:

```bash
# Install Prometheus Operator
kubectl create namespace monitoring
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring
```

2. **Create custom monitoring configuration**:

```yaml
# monitoring-config.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: ecommerce-monitoring
  namespace: monitoring
  labels:
    team: ecommerce
spec:
  selector:
    matchLabels:
      app: backend
  namespaceSelector:
    matchNames:
    - ecommerce
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
    honorLabels: true
---
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: ecommerce-alerts
  namespace: monitoring
spec:
  groups:
  - name: ecommerce.rules
    rules:
    - alert: HighRequestLatency
      expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{app="backend"}[5m])) > 0.5
      for: 5m
      labels:
        severity: warning
        team: ecommerce
      annotations:
        summary: "High request latency detected"
        description: "95th percentile latency is {{ $value }}s for {{ $labels.instance }}"
    
    - alert: HighErrorRate
      expr: rate(http_requests_total{app="backend",status=~"5.."}[5m]) / rate(http_requests_total{app="backend"}[5m]) > 0.05
      for: 2m
      labels:
        severity: critical
        team: ecommerce
      annotations:
        summary: "High error rate detected"
        description: "Error rate is {{ $value | humanizePercentage }} for {{ $labels.instance }}"
    
    - alert: DatabaseConnectionPoolExhausted
      expr: pg_stat_activity_count{app="postgres"} / pg_settings_max_connections{app="postgres"} > 0.8
      for: 5m
      labels:
        severity: warning
        team: ecommerce
      annotations:
        summary: "Database connection pool nearly exhausted"
        description: "{{ $labels.instance }} is using {{ $value | humanizePercentage }} of available connections"
    
    - alert: PodCrashLooping
      expr: rate(kube_pod_container_status_restarts_total{namespace="ecommerce"}[15m]) > 0
      for: 5m
      labels:
        severity: critical
        team: ecommerce
      annotations:
        summary: "Pod is crash looping"
        description: "Pod {{ $labels.pod }} in namespace {{ $labels.namespace }} is restarting frequently"
```

3. **Configure custom Grafana dashboards**:

```yaml
# grafana-dashboard.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ecommerce-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  ecommerce.json: |
    {
      "dashboard": {
        "id": null,
        "title": "E-commerce Application Dashboard",
        "tags": ["ecommerce", "kubernetes"],
        "timezone": "browser",
        "panels": [
          {
            "id": 1,
            "title": "Request Rate",
            "type": "graph",
            "targets": [
              {
                "expr": "sum(rate(http_requests_total{app=\"backend\"}[5m])) by (instance)",
                "legendFormat": "{{instance}}"
              }
            ],
            "yAxes": [
              {
                "label": "Requests/sec"
              }
            ]
          },
          {
            "id": 2,
            "title": "Response Time",
            "type": "graph",
            "targets": [
              {
                "expr": "histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{app=\"backend\"}[5m])) by (le))",
                "legendFormat": "95th percentile"
              },
              {
                "expr": "histogram_quantile(0.50, sum(rate(http_request_duration_seconds_bucket{app=\"backend\"}[5m])) by (le))",
                "legendFormat": "50th percentile"
              }
            ]
          },
          {
            "id": 3,
            "title": "Error Rate",
            "type": "singlestat",
            "targets": [
              {
                "expr": "sum(rate(http_requests_total{app=\"backend\",status=~\"5..\"}[5m])) / sum(rate(http_requests_total{app=\"backend\"}[5m]))",
                "legendFormat": "Error Rate"
              }
            ],
            "valueMaps": [
              {
                "value": "null",
                "op": "=",
                "text": "0%"
              }
            ],
            "colorBackground": true,
            "thresholds": "0.01,0.05"
          }
        ],
        "time": {
          "from": "now-1h",
          "to": "now"
        },
        "refresh": "30s"
      }
    }
```

**Validation**:
- Verify metrics collection and alerting
- Test dashboard functionality
- Configure alert routing and notifications
- Monitor resource utilization and performance

### 6.2 Distributed Tracing with Jaeger

**Objective**: Implement distributed tracing for microservices observability.

**Steps**:

1. **Deploy Jaeger with Istio**:

```yaml
# jaeger-deployment.yaml
apiVersion: jaegertracing.io/v1
kind: Jaeger
metadata:
  name: jaeger
  namespace: istio-system
spec:
  strategy: production
  storage:
    type: elasticsearch
    elasticsearch:
      nodeCount: 3
      storage:
        size: 50Gi
      redundancyPolicy: SingleRedundancy
  ingress:
    enabled: true
    hosts:
    - jaeger.example.com
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: istio-tracing
  namespace: istio-system
data:
  mesh: |
    defaultConfig:
      proxyStatsMatcher:
        inclusionRegexps:
        - ".*circuit_breakers.*"
        - ".*upstream_rq_retry.*"
        - ".*_cx_.*"
      tracing:
        sampling: 1.0
        zipkin:
          address: jaeger-collector.istio-system:9411
    extensionProviders:
    - name: jaeger
      envoyOtelAls:
        service: jaeger-collector.istio-system
        port: 14268
```

2. **Configure application tracing**:

```javascript
// backend/tracing.js
const { NodeTracerProvider } = require('@opentelemetry/sdk-node');
const { Resource } = require('@opentelemetry/resources');
const { SemanticResourceAttributes } = require('@opentelemetry/semantic-conventions');
const { JaegerExporter } = require('@opentelemetry/exporter-jaeger');
const { BatchSpanProcessor } = require('@opentelemetry/sdk-trace-base');

const provider = new NodeTracerProvider({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: 'ecommerce-backend',
    [SemanticResourceAttributes.SERVICE_VERSION]: process.env.APP_VERSION || '1.0.0',
  }),
});

const jaegerExporter = new JaegerExporter({
  endpoint: process.env.JAEGER_ENDPOINT || 'http://jaeger-collector.istio-system:14268/api/traces',
});

provider.addSpanProcessor(new BatchSpanProcessor(jaegerExporter));
provider.register();

module.exports = provider;
```

**Validation**:
- Trace requests across microservices
- Analyze request flow and bottlenecks
- Monitor trace sampling and performance impact
- Use tracing for debugging and optimization

---

## 🎯 Final Project: Complete Enterprise Kubernetes Platform

### Project Overview
Build a production-ready e-commerce platform on Kubernetes with:
- Multi-service architecture with service mesh
- Advanced deployment patterns and scaling
- Comprehensive monitoring and observability
- Security and compliance controls
- Disaster recovery and backup procedures

### Requirements

1. **Architecture**:
   - Frontend (React), Backend (Node.js), Database (PostgreSQL)
   - Redis cache, RabbitMQ message queue
   - Istio service mesh with mTLS
   - Multi-environment deployment (dev, staging, prod)

2. **Deployment**:
   - GitOps with ArgoCD
   - Blue-green and canary deployments
   - HPA and VPA autoscaling
   - StatefulSets for data services

3. **Monitoring**:
   - Prometheus/Grafana monitoring stack
   - Distributed tracing with Jaeger
   - Log aggregation with ELK/EFK
   - Custom dashboards and alerts

4. **Security**:
   - Network policies and service mesh security
   - RBAC and Pod Security Policies
   - Secret management with sealed secrets
   - Vulnerability scanning and compliance

5. **Operations**:
   - Automated backup and disaster recovery
   - Performance optimization and troubleshooting
   - Capacity planning and cost optimization
   - Documentation and runbooks

### Deliverables

1. **Infrastructure Code**:
   - Terraform/Pulumi for cluster provisioning
   - Helm charts for application deployment
   - Kustomize overlays for environments

2. **CI/CD Pipelines**:
   - Automated testing and security scanning
   - Multi-stage deployment pipelines
   - Automated rollback procedures

3. **Monitoring Setup**:
   - Custom metrics and dashboards
   - Alerting rules and notification channels
   - SLA/SLO definitions and monitoring

4. **Documentation**:
   - Architecture diagrams and design decisions
   - Operational procedures and troubleshooting guides
   - Security policies and compliance documentation

### Success Criteria

- Zero-downtime deployments with <1 minute deployment time
- 99.99% availability with automated failover
- <100ms average response time under normal load
- Automated scaling from 3 to 100+ pods based on demand
- Complete observability with end-to-end tracing
- Security compliance with industry standards
- Disaster recovery with <15 minute RTO and <5 minute RPO

---

## 📚 Additional Resources

- [Kubernetes Official Documentation](https://kubernetes.io/docs/)
- [Istio Service Mesh Guide](https://istio.io/latest/docs/)
- [Prometheus Monitoring Guide](https://prometheus.io/docs/)
- [ArgoCD GitOps Documentation](https://argo-cd.readthedocs.io/)
- [Helm Chart Best Practices](https://helm.sh/docs/chart_best_practices/)

Remember: Kubernetes is about declarative infrastructure and automated operations at enterprise scale! 🚀