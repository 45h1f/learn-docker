#!/bin/bash

# Docker Networking & Storage Demo Script
# Comprehensive demonstration of Docker networking and storage capabilities

cd "$(dirname "$0")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
    echo
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

wait_for_user() {
    echo -e "${YELLOW}Press Enter to continue or Ctrl+C to exit...${NC}"
    read -r
}

cleanup() {
    print_info "Cleaning up resources..."
    
    # Stop and remove containers
    docker stop $(docker ps -aq --filter "label=demo=networking-storage") 2>/dev/null || true
    docker rm $(docker ps -aq --filter "label=demo=networking-storage") 2>/dev/null || true
    
    # Remove networks
    docker network rm frontend-net backend-net database-net secure-net 2>/dev/null || true
    
    # Remove volumes
    docker volume rm app-data logs-data cache-data backup-data 2>/dev/null || true
    
    print_success "Cleanup completed"
}

# Set up cleanup on exit
trap cleanup EXIT

print_header "Docker Networking & Storage Advanced Demo"

print_info "This demo covers:"
echo "  🌐 Advanced networking patterns"
echo "  💾 Storage management strategies"
echo "  🔒 Security and isolation"
echo "  🔄 Multi-tier architectures"
echo "  📊 Performance optimization"
echo

wait_for_user

print_header "Part 1: Advanced Networking Patterns"

print_info "Creating multi-tier network architecture..."

# Create networks with different purposes
print_info "Creating frontend network (public-facing)..."
docker network create \
  --driver bridge \
  --subnet=172.20.0.0/16 \
  --gateway=172.20.0.1 \
  --opt com.docker.network.bridge.name=frontend-br \
  --opt com.docker.network.driver.mtu=1500 \
  --label demo=networking-storage \
  frontend-net

print_info "Creating backend network (internal services)..."
docker network create \
  --driver bridge \
  --subnet=172.21.0.0/16 \
  --gateway=172.21.0.1 \
  --opt com.docker.network.bridge.name=backend-br \
  --label demo=networking-storage \
  backend-net

print_info "Creating database network (isolated)..."
docker network create \
  --driver bridge \
  --subnet=172.22.0.0/16 \
  --gateway=172.22.0.1 \
  --internal \
  --opt com.docker.network.bridge.name=database-br \
  --label demo=networking-storage \
  database-net

print_success "Networks created successfully!"

# Show network details
print_info "Network configuration:"
docker network ls --filter label=demo=networking-storage --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}"

echo
wait_for_user

print_header "Part 2: Storage Volume Management"

print_info "Creating different types of volumes..."

# Create named volumes
docker volume create \
  --driver local \
  --label demo=networking-storage \
  --label tier=database \
  app-data

docker volume create \
  --driver local \
  --label demo=networking-storage \
  --label tier=application \
  logs-data

docker volume create \
  --driver local \
  --label demo=networking-storage \
  --label tier=cache \
  cache-data

docker volume create \
  --driver local \
  --label demo=networking-storage \
  --label tier=backup \
  backup-data

print_success "Volumes created successfully!"

print_info "Volume details:"
docker volume ls --filter label=demo=networking-storage --format "table {{.Name}}\t{{.Driver}}\t{{.Labels}}"

echo
wait_for_user

print_header "Part 3: Multi-Tier Application Deployment"

print_info "Deploying database tier..."
docker run -d \
  --name demo-database \
  --label demo=networking-storage \
  --label tier=database \
  --network database-net \
  --ip 172.22.0.10 \
  --mount source=app-data,target=/var/lib/postgresql/data \
  --mount source=backup-data,target=/backups \
  -e POSTGRES_DB=demoapp \
  -e POSTGRES_USER=admin \
  -e POSTGRES_PASSWORD=secret123 \
  postgres:13-alpine

print_info "Waiting for database to start..."
sleep 3

print_info "Deploying API server (backend tier)..."
docker run -d \
  --name demo-api \
  --label demo=networking-storage \
  --label tier=backend \
  --network backend-net \
  --ip 172.21.0.10 \
  --mount source=logs-data,target=/app/logs \
  --mount type=tmpfs,target=/tmp,tmpfs-size=100m \
  -e DATABASE_URL=postgresql://admin:secret123@demo-database:5432/demoapp \
  alpine:latest \
  sh -c 'echo "API Server Starting..." && while true; do echo "$(date): API Health Check" >> /app/logs/api.log; sleep 30; done'

# Connect API to database network
docker network connect database-net demo-api

print_info "Deploying web server (frontend tier)..."
docker run -d \
  --name demo-web \
  --label demo=networking-storage \
  --label tier=frontend \
  --network frontend-net \
  --ip 172.20.0.10 \
  -p 8080:80 \
  --mount source=logs-data,target=/var/log/nginx \
  nginx:alpine

# Connect web to backend network
docker network connect backend-net demo-web

print_info "Deploying cache service..."
docker run -d \
  --name demo-cache \
  --label demo=networking-storage \
  --label tier=cache \
  --network backend-net \
  --ip 172.21.0.20 \
  --mount source=cache-data,target=/data \
  redis:7-alpine \
  redis-server --appendonly yes

print_success "All services deployed!"

print_info "Service status:"
docker ps --filter label=demo=networking-storage --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo
wait_for_user

print_header "Part 4: Network Connectivity Testing"

print_info "Testing network isolation and connectivity..."

# Test connectivity between tiers
echo "🔍 Testing database isolation..."
print_info "Web server trying to reach database directly (should fail):"
if docker exec demo-web ping -c 1 demo-database 2>/dev/null; then
    print_error "Database is accessible from frontend (security issue!)"
else
    print_success "Database properly isolated from frontend"
fi

echo
print_info "API server trying to reach database (should work):"
if docker exec demo-api ping -c 1 demo-database 2>/dev/null; then
    print_success "API can reach database"
else
    print_error "API cannot reach database"
fi

echo
print_info "Web server trying to reach API (should work):"
if docker exec demo-web ping -c 1 demo-api 2>/dev/null; then
    print_success "Web server can reach API"
else
    print_error "Web server cannot reach API"
fi

echo
print_info "API server trying to reach cache (should work):"
if docker exec demo-api ping -c 1 demo-cache 2>/dev/null; then
    print_success "API can reach cache"
else
    print_error "API cannot reach cache"
fi

echo
wait_for_user

print_header "Part 5: Network Details and Inspection"

print_info "Network configuration details:"

for network in frontend-net backend-net database-net; do
    echo
    echo "=== $network ==="
    docker network inspect $network --format "{{.IPAM.Config}}" | sed 's/map\[/\n  /g' | sed 's/\]//' | sed 's/:/: /g'
    
    echo "Connected containers:"
    docker network inspect $network --format '{{range $k, $v := .Containers}}  {{$v.Name}} ({{$v.IPv4Address}}){{"\n"}}{{end}}'
done

echo
wait_for_user

print_header "Part 6: Storage Performance and Management"

print_info "Testing storage performance and features..."

# Test volume performance
print_info "Writing test data to volumes..."
docker exec demo-database sh -c 'echo "Database test data $(date)" > /var/lib/postgresql/data/test.txt'
docker exec demo-api sh -c 'for i in {1..100}; do echo "Log entry $i: $(date)" >> /app/logs/performance.log; done'
docker exec demo-cache sh -c 'redis-cli SET test:key "Cache test data $(date)"'

print_info "Reading test data from volumes..."
echo "Database volume:"
docker exec demo-database cat /var/lib/postgresql/data/test.txt

echo
echo "Logs volume (last 5 lines):"
docker exec demo-api tail -5 /app/logs/performance.log

echo
echo "Cache data:"
docker exec demo-cache redis-cli GET test:key

echo
print_info "Volume usage statistics:"
docker system df -v | grep -E "(VOLUME NAME|demo)"

echo
wait_for_user

print_header "Part 7: Backup and Data Management"

print_info "Demonstrating backup strategies..."

# Create backup
print_info "Creating database backup..."
docker exec demo-database sh -c 'pg_dump -U admin demoapp > /backups/backup-$(date +%Y%m%d-%H%M%S).sql'

print_info "Creating logs archive..."
docker exec demo-api sh -c 'tar czf /backups/logs-backup-$(date +%Y%m%d-%H%M%S).tar.gz /app/logs/'

print_info "Backup files created:"
docker exec demo-database ls -la /backups/

echo
# Volume backup using external container
print_info "Creating external volume backup..."
docker run --rm \
  --label demo=networking-storage \
  --mount source=app-data,target=/data,readonly \
  --mount type=bind,source=/tmp,target=/backup \
  busybox sh -c 'tar czf /backup/volume-backup-$(date +%Y%m%d-%H%M%S).tar.gz -C /data .'

print_success "Backup created at /tmp/volume-backup-*.tar.gz"

echo
wait_for_user

print_header "Part 8: Advanced Storage Features"

print_info "Demonstrating advanced storage patterns..."

# Create tmpfs mount for high-performance temporary storage
print_info "Creating high-performance cache container with tmpfs..."
docker run -d \
  --name demo-fast-cache \
  --label demo=networking-storage \
  --network backend-net \
  --mount type=tmpfs,target=/cache,tmpfs-size=256m,tmpfs-mode=1777 \
  --mount type=tmpfs,target=/tmp,tmpfs-size=64m \
  alpine:latest \
  sh -c 'while true; do echo "Fast cache data: $(date)" > /cache/fast-$(date +%s).txt; sleep 5; done'

# Test tmpfs performance
sleep 2
print_info "tmpfs cache contents:"
docker exec demo-fast-cache ls -la /cache/ | head -5

print_info "tmpfs memory usage:"
docker exec demo-fast-cache df -h /cache /tmp

echo
# Bind mount example
print_info "Creating development container with bind mounts..."
mkdir -p /tmp/demo-dev/{src,config}
echo "console.log('Hello from bind mount!');" > /tmp/demo-dev/src/app.js
echo "{ \"env\": \"development\" }" > /tmp/demo-dev/config/config.json

docker run -d \
  --name demo-dev \
  --label demo=networking-storage \
  --network frontend-net \
  --mount type=bind,source=/tmp/demo-dev/src,target=/app/src \
  --mount type=bind,source=/tmp/demo-dev/config,target=/app/config,readonly \
  node:16-alpine \
  sh -c 'while true; do echo "Dev server running..."; sleep 30; done'

print_info "Bind mount test - modifying source file:"
echo "console.log('Updated from host!');" > /tmp/demo-dev/src/app.js

print_info "Changes reflected in container:"
docker exec demo-dev cat /app/src/app.js

echo
wait_for_user

print_header "Part 9: Security and Network Policies"

print_info "Implementing network security measures..."

# Create secure network with restricted access
docker network create \
  --driver bridge \
  --subnet=172.30.0.0/16 \
  --opt com.docker.network.bridge.enable_icc=false \
  --label demo=networking-storage \
  secure-net

print_info "Deploying secure service..."
docker run -d \
  --name demo-secure \
  --label demo=networking-storage \
  --network secure-net \
  --read-only \
  --mount type=tmpfs,target=/tmp \
  --cap-drop=ALL \
  --cap-add=NET_BIND_SERVICE \
  --user 1000:1000 \
  alpine:latest \
  sh -c 'while true; do echo "Secure service running..."; sleep 60; done'

print_success "Secure container deployed with restricted capabilities"

print_info "Security features applied:"
echo "  ✓ Read-only filesystem"
echo "  ✓ Non-root user (1000:1000)"
echo "  ✓ Dropped all capabilities except NET_BIND_SERVICE"
echo "  ✓ tmpfs for temporary files"
echo "  ✓ Network isolation"

echo
wait_for_user

print_header "Part 10: Performance Monitoring"

print_info "Monitoring network and storage performance..."

# Network performance test
print_info "Network latency between services:"
echo "Frontend to Backend:"
docker exec demo-web ping -c 3 demo-api 2>/dev/null | grep "time=" | tail -1

echo "Backend to Database:"
docker exec demo-api ping -c 3 demo-database 2>/dev/null | grep "time=" | tail -1

echo "Backend to Cache:"
docker exec demo-api ping -c 3 demo-cache 2>/dev/null | grep "time=" | tail -1

echo
# Storage performance
print_info "Storage I/O performance test:"
echo "Testing write performance to volume:"
docker exec demo-database sh -c 'time sh -c "dd if=/dev/zero of=/var/lib/postgresql/data/test-file bs=1M count=10 && sync"' 2>&1 | grep real

echo "Testing read performance from volume:"
docker exec demo-database sh -c 'time sh -c "dd if=/var/lib/postgresql/data/test-file of=/dev/null bs=1M"' 2>&1 | grep real

echo
# Resource usage
print_info "Container resource usage:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" $(docker ps -q --filter label=demo=networking-storage)

echo
wait_for_user

print_header "Part 11: Troubleshooting Tools"

print_info "Network troubleshooting tools and techniques..."

# Install network tools in a container
print_info "Creating network diagnostic container..."
docker run -d \
  --name demo-nettools \
  --label demo=networking-storage \
  --network backend-net \
  --cap-add=NET_ADMIN \
  nicolaka/netshoot \
  sleep 3600

sleep 2

print_info "Network diagnostic tools available:"
docker exec demo-nettools which nslookup dig tcpdump ss netstat

echo
print_info "DNS resolution test:"
docker exec demo-nettools nslookup demo-database

echo
print_info "Port scanning:"
docker exec demo-nettools nmap -p 5432,6379,80 demo-database demo-cache demo-web 2>/dev/null | grep -E "(PORT|open)"

echo
print_info "Network connections:"
docker exec demo-api ss -tuln 2>/dev/null | head -5

echo
wait_for_user

print_header "Demo Summary"

print_success "Docker Networking & Storage Demo Completed!"

print_info "What you've learned:"
echo "  ✓ Multi-tier network architecture"
echo "  ✓ Network isolation and security"
echo "  ✓ Volume management strategies"
echo "  ✓ Storage performance optimization"
echo "  ✓ Backup and recovery patterns"
echo "  ✓ Advanced storage features (tmpfs, bind mounts)"
echo "  ✓ Security hardening techniques"
echo "  ✓ Performance monitoring"
echo "  ✓ Network troubleshooting"

echo
print_info "Key concepts demonstrated:"
echo "  🌐 Bridge, internal, and custom networks"
echo "  💾 Named volumes, bind mounts, and tmpfs"
echo "  🔒 Network isolation and container security"
echo "  📊 Performance testing and monitoring"
echo "  🛠️ Troubleshooting tools and techniques"

echo
print_info "Production considerations covered:"
echo "  • Network segmentation for security"
echo "  • Storage backup and recovery strategies"
echo "  • Performance optimization techniques"
echo "  • Security hardening best practices"
echo "  • Monitoring and troubleshooting approaches"

echo
print_success "Ready for Module 5: Enterprise Security & Compliance!"

# Cleanup happens automatically via trap