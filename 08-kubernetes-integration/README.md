# Module 8: Kubernetes Integration - From Docker to Container Orchestration

## 🎯 Learning Objectives
After completing this module, you will:
- Understand the transition from Docker Compose to Kubernetes
- Master Kubernetes fundamental concepts and architecture
- Deploy containerized applications at enterprise scale
- Implement advanced deployment patterns and service mesh
- Integrate Docker containers with Kubernetes ecosystems
- Manage persistent storage and networking in Kubernetes

---

## 📚 Table of Contents
1. [Kubernetes Architecture & Concepts](#kubernetes-architecture--concepts)
2. [From Docker to Kubernetes Migration](#from-docker-to-kubernetes-migration)
3. [Pod Management & Container Orchestration](#pod-management--container-orchestration)
4. [Service Discovery & Networking](#service-discovery--networking)
5. [Storage & Data Persistence](#storage--data-persistence)
6. [Advanced Deployment Patterns](#advanced-deployment-patterns)
7. [Service Mesh Integration](#service-mesh-integration)
8. [Enterprise Integration Patterns](#enterprise-integration-patterns)

---

## 1. Kubernetes Architecture & Concepts

### 1.1 Kubernetes vs Docker: Understanding the Relationship

Kubernetes doesn't replace Docker—it orchestrates containers that Docker (or other runtimes) creates:

```
Docker Level:          Kubernetes Level:
┌─────────────────┐    ┌─────────────────────────────────────┐
│   Application   │    │              Cluster                │
├─────────────────┤    ├─────────────────────────────────────┤
│   Container     │    │  Pods → ReplicaSets → Deployments  │
├─────────────────┤    ├─────────────────────────────────────┤
│  Docker Engine  │    │         Node (kubelet)             │
├─────────────────┤    ├─────────────────────────────────────┤
│      Host OS    │    │            Host OS                  │
└─────────────────┘    └─────────────────────────────────────┘
```

### 1.2 Core Kubernetes Components

**Control Plane Components:**
- **API Server**: Central management hub for all operations
- **etcd**: Distributed key-value store for cluster state
- **Scheduler**: Assigns pods to nodes based on resource requirements
- **Controller Manager**: Manages various controllers (deployments, services, etc.)

**Node Components:**
- **kubelet**: Node agent that manages containers
- **kube-proxy**: Network proxy maintaining network rules
- **Container Runtime**: Docker, containerd, CRI-O

### 1.3 Fundamental Kubernetes Objects

#### Pods: The Smallest Deployable Unit
```yaml
# pod-example.yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
  labels:
    app: nginx
spec:
  containers:
  - name: nginx
    image: nginx:1.21-alpine
    ports:
    - containerPort: 80
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
    env:
    - name: ENVIRONMENT
      value: "production"
    volumeMounts:
    - name: nginx-config
      mountPath: /etc/nginx/conf.d
  volumes:
  - name: nginx-config
    configMap:
      name: nginx-config
```

#### ReplicaSets: Ensuring Pod Availability
```yaml
# replicaset-example.yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nginx-replicaset
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.21-alpine
        ports:
        - containerPort: 80
```

#### Deployments: Declarative Application Management
```yaml
# deployment-example.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.21-alpine
        ports:
        - containerPort: 80
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
          initialDelaySeconds: 30
          periodSeconds: 30
```

---

## 2. From Docker to Kubernetes Migration

### 2.1 Docker Compose to Kubernetes Translation

Let's translate a typical Docker Compose application to Kubernetes:

**Original Docker Compose:**
```yaml
# docker-compose.yml
version: '3.8'
services:
  web:
    build: .
    ports:
      - "8080:80"
    environment:
      - DATABASE_URL=postgresql://user:pass@db:5432/myapp
    depends_on:
      - db
    volumes:
      - ./app:/var/www/html

  db:
    image: postgres:13
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: user
      POSTGRES_PASSWORD: pass
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

**Kubernetes Equivalent:**

**Namespace:**
```yaml
# namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: myapp-namespace
  labels:
    name: myapp
```

**ConfigMap for Database Configuration:**
```yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: myapp-namespace
data:
  database_host: "postgres-service"
  database_port: "5432"
  database_name: "myapp"
```

**Secret for Database Credentials:**
```yaml
# secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
  namespace: myapp-namespace
type: Opaque
data:
  postgres-user: dXNlcg==      # base64 encoded "user"
  postgres-password: cGFzcw==  # base64 encoded "pass"
```

**PostgreSQL Deployment:**
```yaml
# postgres-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres-deployment
  namespace: myapp-namespace
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
        image: postgres:13
        env:
        - name: POSTGRES_DB
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: database_name
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: postgres-user
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: postgres-password
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
      volumes:
      - name: postgres-storage
        persistentVolumeClaim:
          claimName: postgres-pvc
```

**Persistent Volume Claim:**
```yaml
# postgres-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: myapp-namespace
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: standard
```

**PostgreSQL Service:**
```yaml
# postgres-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: postgres-service
  namespace: myapp-namespace
spec:
  selector:
    app: postgres
  ports:
  - protocol: TCP
    port: 5432
    targetPort: 5432
  type: ClusterIP
```

**Web Application Deployment:**
```yaml
# web-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-deployment
  namespace: myapp-namespace
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
        image: myapp:latest
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
        - name: DB_NAME
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: database_name
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: postgres-user
        - name: DB_PASS
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: postgres-password
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
```

**Web Service with LoadBalancer:**
```yaml
# web-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: web-service
  namespace: myapp-namespace
spec:
  selector:
    app: web
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  type: LoadBalancer
```

### 2.2 Migration Strategy

**Phase 1: Assessment and Planning**
```bash
# Analyze existing Docker Compose applications
docker-compose config --services
docker-compose images
docker-compose ps --all

# Identify dependencies and data flows
docker network ls
docker volume ls
```

**Phase 2: Kubernetes Cluster Preparation**
```bash
# For local development - minikube
minikube start --memory=4096 --cpus=2

# For cloud deployment - example with GKE
gcloud container clusters create myapp-cluster \
  --num-nodes=3 \
  --machine-type=e2-standard-2 \
  --enable-autoscaling \
  --min-nodes=1 \
  --max-nodes=10
```

**Phase 3: Application Containerization Review**
```dockerfile
# Enhanced Dockerfile for Kubernetes
FROM node:16-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:16-alpine
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001
WORKDIR /app
COPY --from=build --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --chown=nodejs:nodejs . .
USER nodejs
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1
CMD ["npm", "start"]
```

---

## 3. Pod Management & Container Orchestration

### 3.1 Advanced Pod Configurations

#### Multi-Container Pods (Sidecar Pattern)
```yaml
# sidecar-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-sidecar
spec:
  containers:
  # Main application container
  - name: app
    image: myapp:latest
    ports:
    - containerPort: 8080
    volumeMounts:
    - name: shared-logs
      mountPath: /var/log/app

  # Sidecar container for log collection
  - name: log-collector
    image: fluent/fluent-bit:latest
    volumeMounts:
    - name: shared-logs
      mountPath: /var/log/app
    - name: fluent-bit-config
      mountPath: /fluent-bit/etc/
    env:
    - name: FLUENT_ELASTICSEARCH_HOST
      value: "elasticsearch.logging.svc.cluster.local"

  volumes:
  - name: shared-logs
    emptyDir: {}
  - name: fluent-bit-config
    configMap:
      name: fluent-bit-config
```

#### Init Containers for Setup Tasks
```yaml
# init-container-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-init
spec:
  initContainers:
  # Database migration init container
  - name: db-migration
    image: myapp-migrations:latest
    env:
    - name: DATABASE_URL
      valueFrom:
        secretKeyRef:
          name: db-secret
          key: database-url
    command: ['sh', '-c', 'run-migrations.sh']

  # Configuration download init container
  - name: config-downloader
    image: busybox:latest
    command: ['sh', '-c', 'wget -O /shared/config.json http://config-service/config']
    volumeMounts:
    - name: shared-config
      mountPath: /shared

  containers:
  - name: app
    image: myapp:latest
    volumeMounts:
    - name: shared-config
      mountPath: /app/config
    ports:
    - containerPort: 8080

  volumes:
  - name: shared-config
    emptyDir: {}
```

### 3.2 Advanced Deployment Strategies

#### Blue-Green Deployments
```yaml
# blue-green-deployment.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: myapp-rollout
spec:
  replicas: 5
  strategy:
    blueGreen:
      activeService: myapp-active-service
      previewService: myapp-preview-service
      scaleDownDelaySeconds: 30
      prePromotionAnalysis:
        templates:
        - templateName: success-rate
        args:
        - name: service-name
          value: myapp-preview-service
      postPromotionAnalysis:
        templates:
        - templateName: success-rate
        args:
        - name: service-name
          value: myapp-active-service
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: myapp:stable
        ports:
        - containerPort: 8080
```

#### Canary Deployments with Istio
```yaml
# canary-deployment.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: myapp-canary
spec:
  replicas: 10
  strategy:
    canary:
      canaryService: myapp-canary-service
      stableService: myapp-stable-service
      trafficRouting:
        istio:
          virtualService:
            name: myapp-virtualservice
      steps:
      - setWeight: 10
      - pause: {duration: 2m}
      - setWeight: 25
      - pause: {duration: 5m}
      - setWeight: 50
      - pause: {duration: 10m}
      - setWeight: 75
      - pause: {duration: 10m}
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: myapp:latest
```

### 3.3 Resource Management and Scaling

#### Horizontal Pod Autoscaler (HPA)
```yaml
# hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: myapp-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp-deployment
  minReplicas: 3
  maxReplicas: 50
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  - type: Pods
    pods:
      metric:
        name: requests_per_second
      target:
        type: AverageValue
        averageValue: "100"
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 60
```

#### Vertical Pod Autoscaler (VPA)
```yaml
# vpa.yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: myapp-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp-deployment
  updatePolicy:
    updateMode: "Auto"
  resourcePolicy:
    containerPolicies:
    - containerName: myapp
      minAllowed:
        cpu: 100m
        memory: 128Mi
      maxAllowed:
        cpu: 2
        memory: 4Gi
      controlledResources: ["cpu", "memory"]
```

---

## 4. Service Discovery & Networking

### 4.1 Service Types and Use Cases

#### ClusterIP (Internal Communication)
```yaml
# clusterip-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: database-service
spec:
  selector:
    app: database
  ports:
  - protocol: TCP
    port: 5432
    targetPort: 5432
  type: ClusterIP
```

#### NodePort (Development/Testing)
```yaml
# nodeport-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: web-nodeport-service
spec:
  selector:
    app: web
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
    nodePort: 30080
  type: NodePort
```

#### LoadBalancer (Production)
```yaml
# loadbalancer-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: web-loadbalancer-service
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
spec:
  selector:
    app: web
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
  type: LoadBalancer
```

### 4.2 Advanced Networking with Ingress

#### Nginx Ingress Controller
```yaml
# ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/rate-limit: "100"
    nginx.ingress.kubernetes.io/rate-limit-window: "1m"
spec:
  tls:
  - hosts:
    - myapp.example.com
    - api.myapp.example.com
    secretName: myapp-tls
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-service
            port:
              number: 80
  - host: api.myapp.example.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 8080
```

#### Application Gateway with SSL Termination
```yaml
# gateway-ingress.yaml
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: myapp-gateway
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: myapp-credential
    hosts:
    - myapp.example.com
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - myapp.example.com
    tls:
      httpsRedirect: true

---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: myapp-virtualservice
spec:
  hosts:
  - myapp.example.com
  gateways:
  - myapp-gateway
  http:
  - match:
    - uri:
        prefix: /api/
    route:
    - destination:
        host: api-service
        port:
          number: 8080
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: web-service
        port:
          number: 80
```

### 4.3 Network Policies for Security

```yaml
# network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: myapp-network-policy
  namespace: myapp-namespace
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: database
    ports:
    - protocol: TCP
      port: 5432
  - to: []
    ports:
    - protocol: TCP
      port: 443
    - protocol: UDP
      port: 53
```

---

## 5. Storage & Data Persistence

### 5.1 Storage Classes and Dynamic Provisioning

```yaml
# storage-class.yaml
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
```

### 5.2 StatefulSets for Stateful Applications

```yaml
# statefulset-postgres.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres-cluster
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
      containers:
      - name: postgres
        image: postgres:13
        env:
        - name: POSTGRES_DB
          value: myapp
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: username
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
        - name: postgres-config
          mountPath: /etc/postgresql/postgresql.conf
          subPath: postgresql.conf
        readinessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - pg_isready -U $POSTGRES_USER -d $POSTGRES_DB -h localhost
          initialDelaySeconds: 15
          periodSeconds: 5
        livenessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - pg_isready -U $POSTGRES_USER -d $POSTGRES_DB -h localhost
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
```

### 5.3 Backup and Disaster Recovery

```yaml
# backup-cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: postgres-backup
            image: postgres:13
            env:
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgres-secret
                  key: password
            command:
            - /bin/bash
            - -c
            - |
              BACKUP_FILE="backup-$(date +%Y%m%d-%H%M%S).sql"
              pg_dump -h postgres-cluster-0.postgres-headless \
                      -U postgres myapp > /backup/$BACKUP_FILE
              # Upload to S3 or other storage
              aws s3 cp /backup/$BACKUP_FILE s3://my-backups/postgres/
            volumeMounts:
            - name: backup-storage
              mountPath: /backup
          volumes:
          - name: backup-storage
            emptyDir: {}
          restartPolicy: OnFailure
```

---

## 6. Advanced Deployment Patterns

### 6.1 GitOps with ArgoCD

```yaml
# application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/myorg/myapp-config
    targetRevision: HEAD
    path: k8s/overlays/production
  destination:
    server: https://kubernetes.default.svc
    namespace: myapp-production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
    - CreateNamespace=true
    - PrunePropagationPolicy=foreground
    - PruneLast=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

### 6.2 Multi-Environment Management with Kustomize

**Base Configuration:**
```yaml
# base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml
- service.yaml
- configmap.yaml

commonLabels:
  app: myapp
  version: v1.0.0
```

**Production Overlay:**
```yaml
# overlays/production/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
- ../../base

images:
- name: myapp
  newTag: v1.2.3

replicas:
- name: myapp-deployment
  count: 5

patchesStrategicMerge:
- production-config.yaml

resources:
- hpa.yaml
- pdb.yaml
- network-policy.yaml
```

**Production Patches:**
```yaml
# overlays/production/production-config.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-deployment
spec:
  template:
    spec:
      containers:
      - name: myapp
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        env:
        - name: ENVIRONMENT
          value: "production"
        - name: LOG_LEVEL
          value: "warn"
```

---

## 7. Service Mesh Integration

### 7.1 Istio Service Mesh Setup

**Istio Installation:**
```bash
# Install Istio
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH

# Install Istio into cluster
istioctl install --set values.defaultRevision=default -y

# Enable automatic sidecar injection
kubectl label namespace myapp-namespace istio-injection=enabled
```

**Service Mesh Configuration:**
```yaml
# destination-rule.yaml
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: myapp-destination
spec:
  host: myapp-service
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
    trafficPolicy:
      portLevelSettings:
      - port:
          number: 8080
        connectionPool:
          tcp:
            maxConnections: 50
  - name: v2
    labels:
      version: v2
```

### 7.2 Advanced Traffic Management

```yaml
# virtual-service-canary.yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: myapp-canary
spec:
  hosts:
  - myapp-service
  http:
  - match:
    - headers:
        canary:
          exact: "true"
    route:
    - destination:
        host: myapp-service
        subset: v2
  - route:
    - destination:
        host: myapp-service
        subset: v1
      weight: 90
    - destination:
        host: myapp-service
        subset: v2
      weight: 10
    fault:
      delay:
        percentage:
          value: 0.1
        fixedDelay: 5s
```

### 7.3 Service Mesh Security

```yaml
# peer-authentication.yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: myapp-namespace
spec:
  mtls:
    mode: STRICT

---
# authorization-policy.yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: myapp-authz
  namespace: myapp-namespace
spec:
  selector:
    matchLabels:
      app: myapp
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/frontend/sa/frontend-service-account"]
  - to:
    - operation:
        methods: ["GET", "POST"]
        paths: ["/api/*"]
```

---

## 8. Enterprise Integration Patterns

### 8.1 Monitoring and Observability

**Prometheus ServiceMonitor:**
```yaml
# service-monitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: myapp-monitor
  labels:
    app: myapp
spec:
  selector:
    matchLabels:
      app: myapp
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

**Grafana Dashboard ConfigMap:**
```yaml
# grafana-dashboard.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: myapp-dashboard
  labels:
    grafana_dashboard: "1"
data:
  myapp.json: |
    {
      "dashboard": {
        "title": "MyApp Metrics",
        "panels": [
          {
            "title": "Request Rate",
            "type": "graph",
            "targets": [
              {
                "expr": "rate(http_requests_total[5m])",
                "legendFormat": "{{method}} {{status}}"
              }
            ]
          }
        ]
      }
    }
```

### 8.2 Distributed Tracing

```yaml
# jaeger-tracing.yaml
apiVersion: jaegertracing.io/v1
kind: Jaeger
metadata:
  name: jaeger
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
```

### 8.3 Security and Compliance

**Pod Security Policy:**
```yaml
# pod-security-policy.yaml
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: restricted
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
```

**Network Security:**
```yaml
# cilium-network-policy.yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: "myapp-security"
spec:
  endpointSelector:
    matchLabels:
      app: myapp
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: frontend
  egress:
  - toEndpoints:
    - matchLabels:
        app: database
    toPorts:
    - ports:
      - port: "5432"
        protocol: TCP
  - toFQDNs:
    - matchName: "api.external-service.com"
    toPorts:
    - ports:
      - port: "443"
        protocol: TCP
```

---

## 🎯 Key Takeaways

1. **Kubernetes Orchestrates Containers**: Kubernetes doesn't replace Docker but orchestrates Docker containers at scale
2. **Declarative Configuration**: Define desired state, Kubernetes maintains it
3. **Service Discovery**: Built-in DNS and service discovery for microservices
4. **Scalability**: Horizontal and vertical scaling with automation
5. **Security**: Network policies, RBAC, and service mesh for enterprise security
6. **Storage**: Persistent volumes and stateful sets for data persistence
7. **Monitoring**: Comprehensive observability with Prometheus, Grafana, and Jaeger
8. **GitOps**: Infrastructure and application deployment as code

---

## 🚀 Next Steps

- Complete the hands-on exercises in the exercises file
- Explore the interactive demos
- Set up a production-ready Kubernetes cluster
- Implement service mesh for advanced traffic management
- Move to Module 9: Performance & Troubleshooting

Remember: Kubernetes is about declarative infrastructure management and container orchestration at enterprise scale! 🚀