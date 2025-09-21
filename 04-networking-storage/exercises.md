# Module 4: Docker Networking & Storage - Practical Exercises

## 🎯 Exercise 1: Multi-Tier Network Architecture

### Task: Design and Implement Secure Network Segmentation

**Scenario:** You're designing a web application with strict security requirements. Create a network architecture that isolates different tiers while allowing necessary communication.

**Requirements:**
- DMZ network for load balancers (public access)
- Application network for web servers (internal)
- Database network for data services (highly restricted)
- Management network for admin tools (separate access)

**Implementation:**
```bash
# Create networks with specific security requirements
docker network create \
  --driver bridge \
  --subnet=10.0.1.0/24 \
  --gateway=10.0.1.1 \
  --opt com.docker.network.bridge.enable_ip_masquerade=true \
  dmz-network

docker network create \
  --driver bridge \
  --subnet=10.0.2.0/24 \
  --gateway=10.0.2.1 \
  --opt com.docker.network.bridge.enable_icc=false \
  app-network

docker network create \
  --driver bridge \
  --subnet=10.0.3.0/24 \
  --gateway=10.0.3.1 \
  --internal \
  database-network

docker network create \
  --driver bridge \
  --subnet=10.0.4.0/24 \
  --gateway=10.0.4.1 \
  --internal \
  mgmt-network

# Deploy services according to security zones
# Load Balancer (DMZ only)
docker run -d --name lb \
  --network dmz-network \
  --ip 10.0.1.10 \
  -p 80:80 -p 443:443 \
  nginx:alpine

# Web Servers (DMZ + App networks)
docker run -d --name web1 \
  --network app-network \
  --ip 10.0.2.10 \
  nginx:alpine

docker network connect dmz-network web1 --ip 10.0.1.20

# API Server (App + Database networks)
docker run -d --name api \
  --network app-network \
  --ip 10.0.2.20 \
  my-api:latest

docker network connect database-network api --ip 10.0.3.20

# Database (Database network only)
docker run -d --name db \
  --network database-network \
  --ip 10.0.3.10 \
  postgres:13-alpine

# Management Tools (Management network)
docker run -d --name pgadmin \
  --network mgmt-network \
  --ip 10.0.4.10 \
  dpage/pgadmin4:latest
```

**Validation Tasks:**
1. Verify that web servers cannot directly access the database
2. Confirm that the load balancer can reach web servers
3. Test that API servers can communicate with the database
4. Ensure management tools are isolated from application networks

**Expected Learning:**
- Network segmentation strategies
- Security through isolation
- Multi-network container configuration
- Network policy implementation

---

## 🎯 Exercise 2: Advanced Volume Management

### Task: Implement Comprehensive Storage Strategy

**Scenario:** Design a storage solution for a data-intensive application that requires:
- High-performance storage for active data
- Archival storage for historical data
- Backup storage with retention policies
- Development storage with quick reset capabilities

**Implementation:**
```bash
# Create volume hierarchy
# High-performance storage (SSD simulation)
docker volume create \
  --driver local \
  --opt type=tmpfs \
  --opt device=tmpfs \
  --opt o=size=1g,uid=1000,gid=1000 \
  high-perf-storage

# Standard persistent storage
docker volume create \
  --driver local \
  --label tier=standard \
  --label backup=daily \
  standard-storage

# Archive storage (simulated slower storage)
docker volume create \
  --driver local \
  --label tier=archive \
  --label backup=weekly \
  archive-storage

# Backup storage
docker volume create \
  --driver local \
  --label tier=backup \
  --label retention=30days \
  backup-storage

# Development storage (disposable)
docker volume create \
  --driver local \
  --label tier=development \
  --label backup=none \
  dev-storage

# Deploy application with tiered storage
docker run -d --name app-main \
  --mount source=high-perf-storage,target=/app/cache \
  --mount source=standard-storage,target=/app/data \
  --mount source=archive-storage,target=/app/archive \
  --mount source=backup-storage,target=/app/backups \
  --mount type=tmpfs,target=/tmp,tmpfs-size=256m \
  my-app:latest

# Backup automation container
docker run -d --name backup-service \
  --mount source=standard-storage,target=/data,readonly \
  --mount source=archive-storage,target=/archive,readonly \
  --mount source=backup-storage,target=/backups \
  --mount type=bind,source=/host/backup-scripts,target=/scripts,readonly \
  backup-tool:latest
```

**Tasks:**
1. Implement automated backup rotation
2. Create data migration between storage tiers
3. Set up monitoring for storage usage
4. Implement disaster recovery procedures

---

## 🎯 Exercise 3: Performance Optimization Lab

### Task: Optimize Network and Storage Performance

**Setup Performance Testing Environment:**
```bash
# Create performance test network
docker network create \
  --driver bridge \
  --opt com.docker.network.driver.mtu=9000 \
  --opt com.docker.network.bridge.enable_ip_masquerade=false \
  perf-network

# High-performance storage
docker volume create \
  --driver local \
  --opt type=ext4 \
  --opt o=noatime,nodiratime \
  perf-storage

# Database with optimized settings
docker run -d --name perf-db \
  --network perf-network \
  --mount source=perf-storage,target=/var/lib/postgresql/data \
  --mount type=tmpfs,target=/tmp,tmpfs-size=512m \
  --shm-size=1g \
  -e POSTGRES_SHARED_PRELOAD_LIBRARIES=pg_stat_statements \
  postgres:13-alpine \
  -c shared_buffers=256MB \
  -c effective_cache_size=1GB \
  -c maintenance_work_mem=64MB

# Application with connection pooling
docker run -d --name perf-app \
  --network perf-network \
  --mount type=tmpfs,target=/tmp,tmpfs-size=256m \
  --ulimit nofile=65536:65536 \
  my-app:optimized

# Load testing container
docker run -d --name load-tester \
  --network perf-network \
  --mount type=bind,source=/host/test-data,target=/data,readonly \
  load-testing:latest
```

**Performance Tests:**
1. Network latency and throughput testing
2. Storage I/O performance benchmarking
3. Concurrent connection handling
4. Memory usage optimization

---

## 🎯 Exercise 4: Service Mesh Implementation

### Task: Implement Microservices Communication Patterns

**Deploy Service Mesh Architecture:**
```bash
# Create service mesh networks
docker network create --driver bridge service-mesh
docker network create --driver bridge sidecar-mesh

# Deploy services with sidecar proxies
for service in user-service order-service payment-service; do
  # Main service
  docker run -d --name ${service} \
    --network service-mesh \
    --label service=${service} \
    ${service}:latest
    
  # Sidecar proxy
  docker run -d --name ${service}-proxy \
    --network container:${service} \
    --label proxy-for=${service} \
    envoy:latest
done

# Service discovery container
docker run -d --name service-discovery \
  --network service-mesh \
  --mount type=bind,source=/host/consul-config,target=/consul/config,readonly \
  consul:latest

# API Gateway
docker run -d --name api-gateway \
  --network service-mesh \
  -p 8080:8080 \
  --mount type=bind,source=/host/gateway-config,target=/config,readonly \
  kong:latest
```

**Service Mesh Features to Implement:**
1. Service discovery and registration
2. Load balancing between service instances
3. Circuit breaker patterns
4. Distributed tracing
5. Security policies (mTLS)

---

## 🎯 Exercise 5: Disaster Recovery Simulation

### Task: Test Backup and Recovery Procedures

**Setup Disaster Recovery Environment:**
```bash
# Primary site volumes
docker volume create primary-db-data
docker volume create primary-app-data
docker volume create primary-logs

# Backup site volumes
docker volume create backup-db-data
docker volume create backup-app-data
docker volume create backup-logs

# Replication setup
docker run -d --name primary-db \
  --mount source=primary-db-data,target=/var/lib/postgresql/data \
  --mount source=backup-db-data,target=/backup \
  -e POSTGRES_REPLICATION_MODE=master \
  postgres:13-alpine

docker run -d --name backup-db \
  --mount source=backup-db-data,target=/var/lib/postgresql/data \
  -e POSTGRES_REPLICATION_MODE=slave \
  -e POSTGRES_MASTER_HOST=primary-db \
  postgres:13-alpine

# Continuous backup service
docker run -d --name backup-service \
  --mount source=primary-db-data,target=/primary,readonly \
  --mount source=primary-app-data,target=/app-data,readonly \
  --mount type=bind,source=/host/backups,target=/backups \
  backup-tool:latest
```

**Disaster Recovery Tests:**
1. Simulate primary database failure
2. Test failover to backup systems
3. Verify data consistency after recovery
4. Measure recovery time objectives (RTO)
5. Validate recovery point objectives (RPO)

---

## 🎯 Exercise 6: Security Hardening Workshop

### Task: Implement Container and Network Security

**Secure Network Configuration:**
```bash
# Create security-hardened networks
docker network create \
  --driver bridge \
  --subnet=192.168.100.0/24 \
  --opt com.docker.network.bridge.enable_icc=false \
  --opt com.docker.network.bridge.enable_ip_masquerade=false \
  secure-frontend

docker network create \
  --driver bridge \
  --subnet=192.168.101.0/24 \
  --internal \
  --opt encrypted=true \
  secure-backend

# Deploy hardened containers
docker run -d --name secure-web \
  --network secure-frontend \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=50m \
  --tmpfs /var/cache/nginx:rw,size=10m \
  --cap-drop=ALL \
  --cap-add=NET_BIND_SERVICE \
  --user 1000:1000 \
  --security-opt=no-new-privileges:true \
  --security-opt=apparmor:docker-default \
  nginx:alpine

# Network policy enforcement (using external tools)
docker run -d --name policy-engine \
  --network secure-backend \
  --cap-add=NET_ADMIN \
  --mount type=bind,source=/host/policies,target=/policies,readonly \
  policy-enforcer:latest
```

**Security Validation:**
1. Container escape prevention testing
2. Network traffic filtering verification
3. Privilege escalation protection
4. Secret management validation
5. Compliance scanning

---

## 🎯 Exercise 7: Monitoring and Observability

### Task: Implement Comprehensive Monitoring

**Monitoring Stack Deployment:**
```bash
# Monitoring network
docker network create monitoring-net

# Prometheus for metrics
docker run -d --name prometheus \
  --network monitoring-net \
  -p 9090:9090 \
  --mount type=bind,source=/host/prometheus-config,target=/etc/prometheus,readonly \
  --mount source=prometheus-data,target=/prometheus \
  prom/prometheus:latest

# Grafana for visualization
docker run -d --name grafana \
  --network monitoring-net \
  -p 3000:3000 \
  --mount source=grafana-data,target=/var/lib/grafana \
  grafana/grafana:latest

# Network monitoring
docker run -d --name network-monitor \
  --network monitoring-net \
  --cap-add=NET_ADMIN \
  --cap-add=NET_RAW \
  --mount type=bind,source=/proc,target=/host/proc,readonly \
  --mount type=bind,source=/sys,target=/host/sys,readonly \
  network-monitoring:latest

# Storage monitoring
docker run -d --name storage-monitor \
  --network monitoring-net \
  --mount type=bind,source=/,target=/rootfs,readonly \
  --mount type=bind,source=/var/run,target=/var/run \
  storage-monitoring:latest
```

**Monitoring Objectives:**
1. Network performance metrics
2. Storage I/O monitoring
3. Container resource utilization
4. Application performance monitoring
5. Security event logging

---

## 🧪 Challenge Exercise: Enterprise Infrastructure

### Task: Build Complete Enterprise Infrastructure

**Requirements:**
Design and implement a complete enterprise infrastructure that includes:

1. **Multi-environment support** (dev/staging/prod)
2. **High availability** with load balancing
3. **Data replication** and backup strategies
4. **Security hardening** at all levels
5. **Monitoring and alerting** systems
6. **Disaster recovery** capabilities
7. **Performance optimization** throughout

**Architecture Components:**
- Load balancers (HAProxy/Nginx)
- Web application tier (multiple instances)
- API services (microservices architecture)
- Database cluster (master-slave replication)
- Cache layer (Redis cluster)
- Message queue (RabbitMQ)
- Monitoring stack (Prometheus/Grafana)
- Logging aggregation (ELK stack)
- Security scanning (vulnerability assessment)

**Deliverables:**
1. Network architecture diagram
2. Storage strategy documentation
3. Security implementation plan
4. Disaster recovery procedures
5. Performance benchmarking results
6. Monitoring dashboards
7. Automation scripts

**Validation Criteria:**
- Zero-downtime deployments
- Sub-second failover times
- Complete data recovery capability
- Security compliance verification
- Performance benchmarks met
- Comprehensive monitoring coverage

---

## 📊 Exercise Results Matrix

| Exercise | Network Skills | Storage Skills | Security Skills | Performance Skills |
|----------|---------------|----------------|-----------------|-------------------|
| Exercise 1 | ✓✓✓ | ✓ | ✓✓✓ | ✓ |
| Exercise 2 | ✓ | ✓✓✓ | ✓ | ✓✓ |
| Exercise 3 | ✓✓ | ✓✓ | ✓ | ✓✓✓ |
| Exercise 4 | ✓✓✓ | ✓ | ✓✓ | ✓✓ |
| Exercise 5 | ✓ | ✓✓✓ | ✓✓ | ✓ |
| Exercise 6 | ✓✓ | ✓ | ✓✓✓ | ✓ |
| Exercise 7 | ✓✓ | ✓✓ | ✓ | ✓✓✓ |
| Challenge | ✓✓✓ | ✓✓✓ | ✓✓✓ | ✓✓✓ |

---

## 🎓 Completion Checklist

### Network Mastery:
- [ ] Create and manage custom bridge networks
- [ ] Implement network segmentation for security
- [ ] Configure overlay networks for multi-host communication
- [ ] Set up macvlan networks for MAC address assignment
- [ ] Troubleshoot network connectivity issues
- [ ] Implement network policies and restrictions

### Storage Mastery:
- [ ] Design volume strategies for different use cases
- [ ] Implement backup and recovery procedures
- [ ] Configure high-performance storage solutions
- [ ] Manage data lifecycle and retention
- [ ] Set up data replication strategies
- [ ] Optimize storage for different workloads

### Security Implementation:
- [ ] Configure network isolation and segmentation
- [ ] Implement container security hardening
- [ ] Set up encrypted communications
- [ ] Configure access controls and policies
- [ ] Implement security monitoring and alerting
- [ ] Conduct security vulnerability assessments

### Performance Optimization:
- [ ] Benchmark network and storage performance
- [ ] Optimize container resource allocation
- [ ] Implement caching strategies
- [ ] Configure load balancing and scaling
- [ ] Monitor and tune system performance
- [ ] Implement performance alerting

---

**🔧 Troubleshooting Guide:**

1. **Network Issues:**
   - Check network connectivity with `ping` and `telnet`
   - Inspect network configuration with `docker network inspect`
   - Verify DNS resolution within containers
   - Check firewall and iptables rules

2. **Storage Problems:**
   - Verify volume mounts and permissions
   - Check disk space and inode usage
   - Monitor I/O performance with `iostat`
   - Validate backup and restore procedures

3. **Performance Issues:**
   - Profile resource usage with `docker stats`
   - Analyze network latency and throughput
   - Monitor storage I/O patterns
   - Tune container resource limits

4. **Security Concerns:**
   - Audit container configurations
   - Scan for vulnerabilities regularly
   - Review network access policies
   - Monitor security logs and events

Continue to: [Module 5: Enterprise Security & Compliance](../05-security-compliance/README.md)