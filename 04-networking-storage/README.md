# Module 4: Docker Networking & Storage

## 🎯 Learning Objectives
- Master Docker networking concepts and types
- Understand bridge, overlay, macvlan, and host networks
- Implement custom networks and network policies
- Master volume management and persistent storage
- Learn bind mounts, tmpfs, and volume drivers
- Apply network security and isolation strategies

## 📖 Theory: Docker Networking Deep Dive

### Docker Networking Architecture

Docker networking is built on a pluggable architecture using Container Network Model (CNM):

```
┌─────────────────────────────────────────────────────────────┐
│                    Docker Host                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ Container A │  │ Container B │  │ Container C │        │
│  │             │  │             │  │             │        │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘        │
│         │                │                │               │
│  ┌──────▼────────────────▼────────────────▼──────┐        │
│  │              Virtual Bridge                    │        │
│  │                (docker0)                      │        │
│  └───────────────────────┬───────────────────────┘        │
│                          │                                │
│  ┌───────────────────────▼───────────────────────┐        │
│  │              Host Network Interface            │        │
│  └───────────────────────────────────────────────┘        │
└─────────────────────────────────────────────────────────────┘
```

### Network Drivers

| Driver | Use Case | Scope | Description |
|--------|----------|-------|-------------|
| **bridge** | Single host | Local | Default network for containers |
| **host** | Single host | Local | Remove network isolation |
| **overlay** | Multi-host | Swarm | Cross-host communication |
| **macvlan** | Single host | Local | Assign MAC addresses |
| **none** | Isolation | Local | Disable networking |
| **custom** | Specialized | Various | Third-party drivers |

## 🌐 Docker Network Types

### 1. Bridge Networks (Default)

**Default Bridge:**
```bash
# Containers on default bridge
docker run -d --name web1 nginx
docker run -d --name web2 nginx

# Check network
docker network inspect bridge
```

**Custom Bridge (Recommended):**
```bash
# Create custom bridge
docker network create --driver bridge my-app-network

# Run containers on custom bridge
docker run -d --name web1 --network my-app-network nginx
docker run -d --name web2 --network my-app-network nginx

# Test communication (containers can reach each other by name)
docker exec web1 ping web2
```

**Advanced Bridge Configuration:**
```bash
# Create bridge with custom subnet
docker network create \
  --driver bridge \
  --subnet=192.168.1.0/24 \
  --ip-range=192.168.1.128/25 \
  --gateway=192.168.1.1 \
  --opt com.docker.network.bridge.name=my-bridge \
  custom-bridge

# Run container with static IP
docker run -d --name web --network custom-bridge --ip 192.168.1.100 nginx
```

### 2. Host Networks

```bash
# Use host networking (container shares host's network stack)
docker run -d --name web --network host nginx

# Container uses host's ports directly (no port mapping needed)
curl http://localhost:80
```

**Use Cases:**
- High performance networking
- Legacy applications
- Network monitoring tools

**Limitations:**
- No network isolation
- Port conflicts
- Security concerns

### 3. Overlay Networks (Docker Swarm)

```bash
# Initialize swarm
docker swarm init

# Create overlay network
docker network create \
  --driver overlay \
  --attachable \
  multi-host-network

# Deploy service across multiple nodes
docker service create \
  --name web \
  --network multi-host-network \
  --replicas 3 \
  nginx
```

### 4. Macvlan Networks

```bash
# Create macvlan network
docker network create \
  --driver macvlan \
  --subnet=192.168.1.0/24 \
  --gateway=192.168.1.1 \
  --opt parent=eth0 \
  macvlan-network

# Container gets its own MAC address
docker run -d --name web --network macvlan-network nginx
```

**Use Cases:**
- Legacy applications requiring MAC addresses
- Network appliances
- DHCP clients

## 🔧 Hands-on Lab 1: Advanced Networking

Let's create a comprehensive networking scenario with multiple networks and services:

### Step 1: Create Network Infrastructure
```bash
# Frontend network (public-facing)
docker network create \
  --driver bridge \
  --subnet=172.20.0.0/16 \
  --gateway=172.20.0.1 \
  --opt com.docker.network.driver.mtu=1500 \
  frontend-network

# Backend network (internal services)
docker network create \
  --driver bridge \
  --subnet=172.21.0.0/16 \
  --gateway=172.21.0.1 \
  --internal \
  backend-network

# Database network (isolated)
docker network create \
  --driver bridge \
  --subnet=172.22.0.0/16 \
  --gateway=172.22.0.1 \
  --internal \
  database-network
```

### Step 2: Deploy Multi-Network Application
```bash
# Database (only on database network)
docker run -d \
  --name postgres-db \
  --network database-network \
  --ip 172.22.0.10 \
  -e POSTGRES_DB=app \
  -e POSTGRES_USER=admin \
  -e POSTGRES_PASSWORD=secret \
  postgres:13-alpine

# Backend API (connected to backend and database networks)
docker run -d \
  --name api-server \
  --network backend-network \
  --ip 172.21.0.10 \
  -e DATABASE_URL=postgresql://admin:secret@postgres-db:5432/app \
  my-api:latest

# Connect API to database network
docker network connect database-network api-server

# Frontend web server (connected to frontend and backend networks)
docker run -d \
  --name web-server \
  --network frontend-network \
  --ip 172.20.0.10 \
  -p 8080:80 \
  -e API_URL=http://api-server:3000 \
  my-web:latest

# Connect web server to backend network
docker network connect backend-network web-server

# Load balancer (only on frontend network)
docker run -d \
  --name load-balancer \
  --network frontend-network \
  --ip 172.20.0.5 \
  -p 80:80 \
  -p 443:443 \
  nginx:alpine
```

### Step 3: Network Security and Isolation
```bash
# Test network isolation
docker exec web-server ping postgres-db  # Should fail (no direct access)
docker exec api-server ping postgres-db  # Should work (connected)

# Check network connectivity
docker network inspect frontend-network backend-network database-network
```

## 💾 Docker Storage Deep Dive

### Storage Types

| Type | Use Case | Performance | Persistence | Sharing |
|------|----------|-------------|-------------|---------|
| **Volumes** | Production data | Good | Yes | Multi-container |
| **Bind Mounts** | Development | Best | Yes | Host filesystem |
| **tmpfs** | Temporary data | Excellent | No | Single container |

### Volume Management

**Named Volumes:**
```bash
# Create named volume
docker volume create \
  --driver local \
  --opt type=ext4 \
  --opt device=/dev/sdb1 \
  app-data

# Use volume
docker run -d \
  --name database \
  --mount source=app-data,target=/var/lib/postgresql/data \
  postgres:13

# Inspect volume
docker volume inspect app-data

# List volumes
docker volume ls

# Remove unused volumes
docker volume prune
```

**Volume Drivers:**
```bash
# NFS volume
docker volume create \
  --driver local \
  --opt type=nfs \
  --opt o=addr=192.168.1.100,rw \
  --opt device=:/path/to/nfs/share \
  nfs-volume

# CIFS/SMB volume
docker volume create \
  --driver local \
  --opt type=cifs \
  --opt o=username=user,password=pass \
  --opt device=//server/share \
  smb-volume
```

### Bind Mounts

```bash
# Development bind mount
docker run -d \
  --name dev-app \
  --mount type=bind,source=/host/path,target=/app \
  my-app:dev

# Read-only bind mount
docker run -d \
  --name config-app \
  --mount type=bind,source=/host/config,target=/app/config,readonly \
  my-app:latest

# Bind mount with options
docker run -d \
  --name secure-app \
  --mount type=bind,source=/host/data,target=/app/data,bind-propagation=private \
  my-app:latest
```

### tmpfs Mounts

```bash
# Temporary filesystem in memory
docker run -d \
  --name temp-app \
  --mount type=tmpfs,target=/tmp,tmpfs-size=100m,tmpfs-mode=1777 \
  my-app:latest

# Multiple tmpfs mounts
docker run -d \
  --name cache-app \
  --tmpfs /tmp:rw,noexec,nosuid,size=100m \
  --tmpfs /var/cache:rw,size=50m \
  my-app:latest
```

## 🏗️ Hands-on Lab 2: Advanced Storage Scenarios

Let's create comprehensive storage examples for different use cases:

### Scenario 1: Development Environment with Live Reload
```bash
# Create development setup with bind mounts
mkdir -p /tmp/dev-project/{src,config,logs}

# Development container with live code reload
docker run -d \
  --name dev-environment \
  --mount type=bind,source=/tmp/dev-project/src,target=/app/src \
  --mount type=bind,source=/tmp/dev-project/config,target=/app/config,readonly \
  --mount type=volume,source=dev-logs,target=/app/logs \
  --mount type=tmpfs,target=/tmp,tmpfs-size=500m \
  -p 3000:3000 \
  node:16-alpine \
  sh -c "cd /app && npm run dev"
```

### Scenario 2: Database with Backup Strategy
```bash
# Create volumes for database and backups
docker volume create postgres-data
docker volume create postgres-backups

# Database container
docker run -d \
  --name production-db \
  --mount source=postgres-data,target=/var/lib/postgresql/data \
  --mount source=postgres-backups,target=/backups \
  -e POSTGRES_DB=production \
  -e POSTGRES_USER=admin \
  -e POSTGRES_PASSWORD=secure-password \
  postgres:13-alpine

# Backup script container
docker run -d \
  --name db-backup \
  --mount source=postgres-data,target=/var/lib/postgresql/data,readonly \
  --mount source=postgres-backups,target=/backups \
  --link production-db:db \
  postgres:13-alpine \
  sh -c 'while true; do 
    pg_dump -h db -U admin production > /backups/backup-$(date +%Y%m%d-%H%M%S).sql
    find /backups -name "backup-*.sql" -mtime +7 -delete
    sleep 86400
  done'
```

### Scenario 3: Microservices with Shared Storage
```bash
# Shared volume for microservices
docker volume create shared-uploads

# Upload service
docker run -d \
  --name upload-service \
  --mount source=shared-uploads,target=/uploads \
  -p 8001:8000 \
  upload-service:latest

# Processing service
docker run -d \
  --name process-service \
  --mount source=shared-uploads,target=/uploads,readonly \
  --mount type=tmpfs,target=/tmp/processing,tmpfs-size=1g \
  process-service:latest

# Delivery service
docker run -d \
  --name delivery-service \
  --mount source=shared-uploads,target=/uploads,readonly \
  -p 8003:8000 \
  delivery-service:latest
```

## 🔐 Network Security Best Practices

### 1. Network Segmentation
```bash
# Create isolated networks for different tiers
docker network create --internal dmz-network
docker network create --internal app-network  
docker network create --internal db-network

# Use network aliases for service discovery
docker run -d \
  --name web \
  --network dmz-network \
  --network-alias frontend \
  web-app:latest
```

### 2. Custom Bridge Configuration
```bash
# Create secure bridge with custom settings
docker network create \
  --driver bridge \
  --subnet=10.1.0.0/16 \
  --opt com.docker.network.bridge.enable_icc=false \
  --opt com.docker.network.bridge.enable_ip_masquerade=true \
  --opt com.docker.network.driver.mtu=1450 \
  secure-network
```

### 3. Network Policies (with external tools)
```bash
# Example with Calico (requires setup)
# Create network policy to deny all traffic
cat > deny-all-policy.yaml << 'EOF'
apiVersion: projectcalico.org/v3
kind: NetworkPolicy
metadata:
  name: deny-all
spec:
  selector: all()
  types:
  - Ingress
  - Egress
EOF
```

## 📊 Network Monitoring and Troubleshooting

### Network Inspection Commands
```bash
# List all networks
docker network ls

# Inspect network details
docker network inspect bridge

# Show network connectivity
docker inspect container-name | grep -A 10 NetworkSettings

# Monitor network traffic
docker exec container-name netstat -i
docker exec container-name ss -tuln

# Test connectivity
docker exec container1 ping container2
docker exec container1 nslookup container2
docker exec container1 telnet container2 port
```

### Performance Monitoring
```bash
# Network performance testing
docker run --rm -it \
  --network my-network \
  nicolaka/netshoot \
  iperf3 -c target-container

# Bandwidth monitoring
docker exec container-name iftop
docker exec container-name nload

# Packet capture
docker exec container-name tcpdump -i eth0 -w /tmp/capture.pcap
```

## 🧪 Advanced Storage Patterns

### 1. Storage Plugins and Drivers
```bash
# Install volume plugin (example: Convoy)
docker plugin install store/rancher/convoy-nfs:latest

# Create volume with plugin
docker volume create \
  --driver convoy-nfs \
  --opt server=nfs-server \
  --opt export=/exports/data \
  nfs-data
```

### 2. Backup and Restore Strategies
```bash
# Backup volume data
docker run --rm \
  --mount source=app-data,target=/data,readonly \
  --mount type=bind,source=/host/backups,target=/backup \
  busybox tar czf /backup/app-data-backup-$(date +%Y%m%d).tar.gz -C /data .

# Restore volume data
docker run --rm \
  --mount source=app-data,target=/data \
  --mount type=bind,source=/host/backups,target=/backup,readonly \
  busybox tar xzf /backup/app-data-backup-20231201.tar.gz -C /data
```

### 3. Volume Migration
```bash
# Migrate volume between hosts
# Source host
docker run --rm \
  --mount source=source-volume,target=/data,readonly \
  busybox tar cz -C /data . | ssh target-host 'docker run --rm -i --mount source=target-volume,target=/data busybox tar xz -C /data'
```

## 🔧 Container-to-Container Communication Patterns

### 1. Service Discovery
```bash
# Using DNS (automatic with custom networks)
docker network create app-net
docker run -d --name api --network app-net api-service:latest
docker run -d --name web --network app-net web-service:latest
# web can reach api using hostname "api"
```

### 2. Load Balancing
```bash
# Multiple backend instances
docker run -d --name api1 --network app-net api-service:latest
docker run -d --name api2 --network app-net api-service:latest  
docker run -d --name api3 --network app-net api-service:latest

# Load balancer configuration
docker run -d --name lb \
  --network app-net \
  -p 80:80 \
  -v $(pwd)/nginx.conf:/etc/nginx/nginx.conf \
  nginx:alpine
```

### 3. Service Mesh Pattern
```bash
# Sidecar proxy pattern
docker run -d --name app-proxy \
  --network container:main-app \
  envoyproxy/envoy:latest

docker run -d --name main-app \
  --network app-net \
  main-service:latest
```

## 📝 Production Storage Considerations

### 1. Performance Optimization
```bash
# High-performance volume with specific options
docker volume create \
  --driver local \
  --opt type=ext4 \
  --opt o=noatime,nodiratime \
  --opt device=/dev/nvme0n1p1 \
  high-perf-volume
```

### 2. Disaster Recovery
```bash
# Replicated storage setup
docker volume create \
  --driver convoy \
  --opt size=100G \
  --opt backup.target=s3://backup-bucket \
  --opt backup.schedule="0 2 * * *" \
  replicated-volume
```

### 3. Security Considerations
```bash
# Encrypted volume
docker volume create \
  --driver local \
  --opt type=ext4 \
  --opt o=loop,encryption=aes256 \
  --opt device=/encrypted/storage/file \
  encrypted-volume
```

This covers the comprehensive networking and storage capabilities of Docker. Each concept builds upon previous knowledge while providing practical, enterprise-ready examples that you'll use in production environments.