# Module 6: Production Deployment Strategies - Exercises

## 🎯 Exercise Overview

These exercises will help you master production deployment strategies, including blue-green deployments, rolling updates, health checks, and monitoring systems. Each exercise builds production-ready deployment capabilities.

---

## Exercise 1: Blue-Green Deployment Implementation 🔄

**Objective**: Implement a complete blue-green deployment system with automated traffic switching and rollback capabilities.

### Task 1.1: Production Application Setup

Create a production-ready application with proper health checks:

```javascript
// production-web-app.js
const express = require('express');
const prometheus = require('prom-client');
const app = express();

// Prometheus metrics
const httpRequestDuration = new prometheus.Histogram({
    name: 'http_request_duration_seconds',
    help: 'Duration of HTTP requests in seconds',
    labelNames: ['method', 'route', 'status_code']
});

const httpRequestsTotal = new prometheus.Counter({
    name: 'http_requests_total',
    help: 'Total number of HTTP requests',
    labelNames: ['method', 'route', 'status_code']
});

// Application state
let isHealthy = true;
let isReady = true;
const startTime = Date.now();

// Middleware for metrics
app.use((req, res, next) => {
    const start = Date.now();
    
    res.on('finish', () => {
        const duration = (Date.now() - start) / 1000;
        const route = req.route ? req.route.path : req.path;
        
        httpRequestDuration
            .labels(req.method, route, res.statusCode)
            .observe(duration);
        
        httpRequestsTotal
            .labels(req.method, route, res.statusCode)
            .inc();
    });
    
    next();
});

app.use(express.json());

// Health endpoints
app.get('/health', (req, res) => {
    if (!isHealthy) {
        return res.status(503).json({
            status: 'unhealthy',
            timestamp: new Date().toISOString(),
            uptime: process.uptime(),
            version: process.env.APP_VERSION || '1.0.0'
        });
    }
    
    res.json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        version: process.env.APP_VERSION || '1.0.0',
        environment: process.env.NODE_ENV || 'development'
    });
});

app.get('/ready', (req, res) => {
    if (!isReady) {
        return res.status(503).json({
            status: 'not ready',
            timestamp: new Date().toISOString()
        });
    }
    
    res.json({
        status: 'ready',
        timestamp: new Date().toISOString(),
        dependencies: {
            database: 'connected',
            cache: 'operational',
            external_apis: 'available'
        }
    });
});

app.get('/live', (req, res) => {
    res.json({
        status: 'alive',
        timestamp: new Date().toISOString(),
        pid: process.pid
    });
});

// Main application routes
app.get('/', (req, res) => {
    res.json({
        message: 'Production Application',
        version: process.env.APP_VERSION || '1.0.0',
        environment: process.env.NODE_ENV || 'development',
        deployment: process.env.DEPLOYMENT_COLOR || 'unknown',
        timestamp: new Date().toISOString()
    });
});

app.get('/api/version', (req, res) => {
    res.json({
        version: process.env.APP_VERSION || '1.0.0',
        build_time: process.env.BUILD_TIME || new Date().toISOString(),
        git_commit: process.env.GIT_COMMIT || 'unknown',
        deployment_color: process.env.DEPLOYMENT_COLOR || 'unknown'
    });
});

// Metrics endpoint
app.get('/metrics', async (req, res) => {
    res.set('Content-Type', prometheus.register.contentType);
    res.end(await prometheus.register.metrics());
});

// Admin endpoints for testing
app.post('/admin/health/toggle', (req, res) => {
    isHealthy = !isHealthy;
    res.json({ healthy: isHealthy });
});

app.post('/admin/ready/toggle', (req, res) => {
    isReady = !isReady;
    res.json({ ready: isReady });
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('SIGTERM received, shutting down gracefully');
    isHealthy = false;
    isReady = false;
    setTimeout(() => process.exit(0), 5000);
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
    console.log(`Production app listening on port ${PORT}`);
    console.log(`Version: ${process.env.APP_VERSION || '1.0.0'}`);
    console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
    console.log(`Deployment Color: ${process.env.DEPLOYMENT_COLOR || 'unknown'}`);
});
```

### Task 1.2: Blue-Green Deployment Automation

```bash
#!/bin/bash
# blue-green-deployment.sh

set -euo pipefail

# Configuration
SERVICE_NAME="web-app"
IMAGE_REPO="myapp"
NEW_VERSION=$1
HEALTH_TIMEOUT=300
SWITCH_DELAY=30

# Load balancer configuration
LB_CONFIG_FILE="nginx-upstream.conf"
LB_CONTAINER="nginx-lb"

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

log_blue() {
    echo -e "${BLUE}🔵 BLUE: $1${NC}"
}

log_green() {
    echo -e "${GREEN}🟢 GREEN: $1${NC}"
}

log_error() {
    echo -e "${RED}❌ ERROR: $1${NC}"
}

# Determine current deployment state
get_current_state() {
    local current_env="none"
    
    if docker ps --filter "name=${SERVICE_NAME}-blue" --filter "status=running" | grep -q "${SERVICE_NAME}-blue"; then
        if docker exec "$LB_CONTAINER" cat /etc/nginx/conf.d/upstream.conf 2>/dev/null | grep -q "blue:3000"; then
            current_env="blue"
        fi
    fi
    
    if docker ps --filter "name=${SERVICE_NAME}-green" --filter "status=running" | grep -q "${SERVICE_NAME}-green"; then
        if docker exec "$LB_CONTAINER" cat /etc/nginx/conf.d/upstream.conf 2>/dev/null | grep -q "green:3000"; then
            current_env="green"
        fi
    fi
    
    echo "$current_env"
}

get_target_env() {
    local current=$1
    case "$current" in
        "blue") echo "green" ;;
        "green") echo "blue" ;;
        *) echo "blue" ;;
    esac
}

# Deploy to target environment
deploy_target_environment() {
    local target_env=$1
    local version=$2
    local container_name="${SERVICE_NAME}-${target_env}"
    local network_alias="$target_env"
    
    if [[ "$target_env" == "blue" ]]; then
        log_blue "Deploying version $version to blue environment"
    else
        log_green "Deploying version $version to green environment"
    fi
    
    # Stop and remove existing container
    docker stop "$container_name" 2>/dev/null || true
    docker rm "$container_name" 2>/dev/null || true
    
    # Deploy new container
    docker run -d \
        --name "$container_name" \
        --network app-network \
        --network-alias "$network_alias" \
        --env NODE_ENV=production \
        --env APP_VERSION="$version" \
        --env DEPLOYMENT_COLOR="$target_env" \
        --env BUILD_TIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --restart unless-stopped \
        --health-cmd "curl -f http://localhost:3000/health || exit 1" \
        --health-interval 30s \
        --health-timeout 10s \
        --health-retries 3 \
        "$IMAGE_REPO:$version"
    
    if [[ "$target_env" == "blue" ]]; then
        log_blue "Blue environment deployment completed"
    else
        log_green "Green environment deployment completed"
    fi
}

# Health check with timeout
wait_for_health() {
    local target_env=$1
    local container_name="${SERVICE_NAME}-${target_env}"
    local timeout=$HEALTH_TIMEOUT
    local elapsed=0
    
    if [[ "$target_env" == "blue" ]]; then
        log_blue "Waiting for blue environment to become healthy..."
    else
        log_green "Waiting for green environment to become healthy..."
    fi
    
    while [[ $elapsed -lt $timeout ]]; do
        if docker exec "$container_name" curl -f -s http://localhost:3000/health >/dev/null 2>&1; then
            if [[ "$target_env" == "blue" ]]; then
                log_blue "Blue environment is healthy ✅"
            else
                log_green "Green environment is healthy ✅"
            fi
            return 0
        fi
        
        log "Health check failed, retrying in 10 seconds... ($elapsed/$timeout)"
        sleep 10
        elapsed=$((elapsed + 10))
    done
    
    log_error "Health check timeout reached for $target_env environment"
    return 1
}

# Update load balancer configuration
update_load_balancer() {
    local target_env=$1
    
    log "Updating load balancer to route traffic to $target_env environment"
    
    # Create new upstream configuration
    cat > temp_upstream.conf << EOF
upstream backend {
    server ${target_env}:3000 max_fails=3 fail_timeout=30s;
}
EOF
    
    # Copy configuration to load balancer
    docker cp temp_upstream.conf "$LB_CONTAINER:/etc/nginx/conf.d/upstream.conf"
    
    # Reload nginx configuration
    docker exec "$LB_CONTAINER" nginx -s reload
    
    # Cleanup
    rm temp_upstream.conf
    
    log "Load balancer updated successfully"
}

# Verify traffic switch
verify_traffic_switch() {
    local target_env=$1
    local max_attempts=10
    local attempt=1
    
    log "Verifying traffic is routed to $target_env environment"
    
    while [[ $attempt -le $max_attempts ]]; do
        local response=$(curl -s http://localhost:80/api/version 2>/dev/null || echo "{}")
        local deployment_color=$(echo "$response" | jq -r '.deployment_color // "unknown"')
        
        if [[ "$deployment_color" == "$target_env" ]]; then
            log "Traffic successfully routed to $target_env environment ✅"
            return 0
        fi
        
        log "Verification attempt $attempt/$max_attempts - detected color: $deployment_color"
        sleep 5
        ((attempt++))
    done
    
    log_error "Traffic verification failed"
    return 1
}

# Rollback function
rollback_deployment() {
    local current_env=$1
    local target_env=$2
    
    log_error "Rolling back deployment from $target_env to $current_env"
    
    if [[ "$current_env" != "none" ]]; then
        # Switch traffic back
        update_load_balancer "$current_env"
        
        # Verify rollback
        if verify_traffic_switch "$current_env"; then
            log "Rollback successful ✅"
        else
            log_error "Rollback verification failed"
        fi
    fi
    
    # Clean up failed deployment
    docker stop "${SERVICE_NAME}-${target_env}" 2>/dev/null || true
    docker rm "${SERVICE_NAME}-${target_env}" 2>/dev/null || true
}

# Cleanup old environment
cleanup_old_environment() {
    local old_env=$1
    
    if [[ "$old_env" != "none" ]]; then
        log "Cleaning up old $old_env environment after $SWITCH_DELAY seconds"
        sleep "$SWITCH_DELAY"
        
        docker stop "${SERVICE_NAME}-${old_env}" 2>/dev/null || true
        docker rm "${SERVICE_NAME}-${old_env}" 2>/dev/null || true
        
        log "Old $old_env environment cleaned up"
    fi
}

# Main deployment function
main() {
    if [[ $# -ne 1 ]]; then
        echo "Usage: $0 <version>"
        echo "Example: $0 v2.1.0"
        exit 1
    fi
    
    log "Starting blue-green deployment for $SERVICE_NAME:$NEW_VERSION"
    
    # Pre-deployment checks
    if ! docker network ls | grep -q "app-network"; then
        log "Creating application network"
        docker network create app-network
    fi
    
    if ! docker ps | grep -q "$LB_CONTAINER"; then
        log_error "Load balancer container not running"
        exit 1
    fi
    
    # Determine deployment environments
    local current_env=$(get_current_state)
    local target_env=$(get_target_env "$current_env")
    
    log "Current environment: $current_env"
    log "Target environment: $target_env"
    
    # Deploy to target environment
    deploy_target_environment "$target_env" "$NEW_VERSION"
    
    # Wait for target environment to be healthy
    if ! wait_for_health "$target_env"; then
        rollback_deployment "$current_env" "$target_env"
        exit 1
    fi
    
    # Switch traffic to target environment
    update_load_balancer "$target_env"
    
    # Verify traffic switch
    if ! verify_traffic_switch "$target_env"; then
        rollback_deployment "$current_env" "$target_env"
        exit 1
    fi
    
    # Cleanup old environment
    cleanup_old_environment "$current_env"
    
    log "🎉 Blue-green deployment completed successfully!"
    log "Active environment: $target_env"
    log "Version: $NEW_VERSION"
}

# Execute main function
main "$@"
```

### Task 1.3: Load Balancer Setup

```yaml
# docker-compose.loadbalancer.yml
version: '3.8'

services:
  nginx-lb:
    image: nginx:alpine
    container_name: nginx-lb
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./upstream.conf:/etc/nginx/conf.d/upstream.conf:rw
    networks:
      - app-network
    restart: unless-stopped

networks:
  app-network:
    driver: bridge
```

```nginx
# nginx.conf
events {
    worker_connections 1024;
}

http {
    include /etc/nginx/conf.d/*.conf;
    
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log;
    
    server {
        listen 80;
        
        location /health {
            proxy_pass http://backend/health;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            access_log off;
        }
        
        location / {
            proxy_pass http://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            proxy_connect_timeout 30s;
            proxy_send_timeout 30s;
            proxy_read_timeout 30s;
            
            proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;
            proxy_next_upstream_tries 3;
            proxy_next_upstream_timeout 30s;
        }
    }
}
```

**Deliverables**:
- [ ] Production application with comprehensive health checks
- [ ] Automated blue-green deployment script
- [ ] Load balancer configuration and setup
- [ ] Traffic verification and rollback mechanisms

---

## Exercise 2: Rolling Update Implementation 📈

**Objective**: Implement a rolling update system with configurable batch sizes and failure handling.

### Task 2.1: Service Orchestration Setup

```yaml
# docker-compose.rolling.yml
version: '3.8'

services:
  web-app:
    image: ${IMAGE_NAME:-myapp:latest}
    deploy:
      replicas: 6
      update_config:
        parallelism: 2
        delay: 30s
        failure_action: rollback
        monitor: 60s
        max_failure_ratio: 0.3
      rollback_config:
        parallelism: 2
        delay: 30s
        failure_action: pause
        monitor: 60s
        max_failure_ratio: 0.3
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
      placement:
        constraints:
          - node.role == worker
    environment:
      - NODE_ENV=production
      - APP_VERSION=${VERSION:-1.0.0}
    networks:
      - app-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./nginx-rolling.conf:/etc/nginx/nginx.conf:ro
    networks:
      - app-network
    depends_on:
      - web-app

networks:
  app-network:
    driver: overlay
```

### Task 2.2: Rolling Update Controller

```bash
#!/bin/bash
# rolling-update-controller.sh

set -euo pipefail

# Configuration
SERVICE_NAME="web-app"
STACK_NAME="production"
COMPOSE_FILE="docker-compose.rolling.yml"
HEALTH_CHECK_ENDPOINT="/health"
BATCH_SIZE=${BATCH_SIZE:-2}
BATCH_DELAY=${BATCH_DELAY:-30}
MAX_FAILURE_RATIO=${MAX_FAILURE_RATIO:-0.3}

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

# Get service information
get_service_info() {
    local service_name="$1"
    docker service inspect "$service_name" --format '{{json .}}' 2>/dev/null || echo "{}"
}

get_service_replicas() {
    local service_name="$1"
    docker service inspect "$service_name" --format '{{.Spec.Mode.Replicated.Replicas}}' 2>/dev/null || echo "0"
}

get_running_replicas() {
    local service_name="$1"
    docker service ps "$service_name" --filter "desired-state=running" --format "{{.CurrentState}}" | grep -c "Running" || echo "0"
}

get_service_image() {
    local service_name="$1"
    docker service inspect "$service_name" --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}' 2>/dev/null || echo ""
}

# Health check functions
health_check_service() {
    local service_name="$1"
    local timeout=${2:-300}
    local elapsed=0
    
    log "Performing health check for service $service_name"
    
    local desired_replicas=$(get_service_replicas "$service_name")
    
    while [[ $elapsed -lt $timeout ]]; do
        local running_replicas=$(get_running_replicas "$service_name")
        
        if [[ "$running_replicas" -eq "$desired_replicas" ]]; then
            # All replicas are running, now check application health
            if check_application_health "$service_name"; then
                success "Health check passed for $service_name"
                return 0
            fi
        fi
        
        log "Health check in progress... ($running_replicas/$desired_replicas replicas running)"
        sleep 10
        elapsed=$((elapsed + 10))
    done
    
    error "Health check timeout for $service_name"
    return 1
}

check_application_health() {
    local service_name="$1"
    local healthy_count=0
    local total_checks=0
    
    # Get all running task IPs (simulation - in real scenario you'd get actual IPs)
    local running_replicas=$(get_running_replicas "$service_name")
    
    for i in $(seq 1 "$running_replicas"); do
        ((total_checks++))
        
        # Simulate health check (90% success rate)
        if [[ $(( RANDOM % 10 )) -lt 9 ]]; then
            ((healthy_count++))
        fi
    done
    
    local health_ratio=$(( healthy_count * 100 / total_checks ))
    
    if [[ $health_ratio -ge 80 ]]; then
        log "Application health check passed ($healthy_count/$total_checks healthy)"
        return 0
    else
        warning "Application health check failed ($healthy_count/$total_checks healthy)"
        return 1
    fi
}

# Update monitoring
monitor_update_progress() {
    local service_name="$1"
    local timeout=${2:-600}
    local elapsed=0
    
    log "Monitoring rolling update progress for $service_name"
    
    while [[ $elapsed -lt $timeout ]]; do
        local update_status=$(docker service inspect "$service_name" --format '{{.UpdateStatus.State}}' 2>/dev/null || echo "unknown")
        
        case "$update_status" in
            "completed")
                success "Rolling update completed successfully"
                return 0
                ;;
            "rollback_completed")
                error "Rolling update failed, rollback completed"
                return 1
                ;;
            "paused")
                warning "Rolling update paused due to failures"
                return 1
                ;;
            "updating")
                local running_replicas=$(get_running_replicas "$service_name")
                local desired_replicas=$(get_service_replicas "$service_name")
                log "Update in progress... ($running_replicas/$desired_replicas replicas ready)"
                ;;
            "rollback_started")
                warning "Rolling update failed, rollback in progress..."
                ;;
            *)
                log "Update status: $update_status"
                ;;
        esac
        
        sleep 15
        elapsed=$((elapsed + 15))
    done
    
    error "Update monitoring timeout"
    return 1
}

# Rolling update execution
perform_rolling_update() {
    local new_image="$1"
    local service_name="${STACK_NAME}_${SERVICE_NAME}"
    
    log "Starting rolling update for $service_name"
    log "Target image: $new_image"
    
    # Get current service state
    local current_image=$(get_service_image "$service_name")
    local current_replicas=$(get_service_replicas "$service_name")
    
    log "Current image: $current_image"
    log "Current replicas: $current_replicas"
    
    if [[ "$current_image" == "$new_image" ]]; then
        warning "Service is already running the target image"
        return 0
    fi
    
    # Update service with new image
    log "Initiating rolling update..."
    
    docker service update \
        --image "$new_image" \
        --update-parallelism "$BATCH_SIZE" \
        --update-delay "${BATCH_DELAY}s" \
        --update-monitor 60s \
        --update-failure-action rollback \
        --update-max-failure-ratio "$MAX_FAILURE_RATIO" \
        "$service_name"
    
    # Monitor update progress
    if ! monitor_update_progress "$service_name"; then
        error "Rolling update failed"
        return 1
    fi
    
    # Final health check
    if ! health_check_service "$service_name"; then
        error "Final health check failed"
        return 1
    fi
    
    success "Rolling update completed successfully!"
    
    # Display final state
    display_service_status "$service_name"
    
    return 0
}

# Display service status
display_service_status() {
    local service_name="$1"
    
    echo ""
    echo "Service Status Summary:"
    echo "======================"
    
    local current_image=$(get_service_image "$service_name")
    local desired_replicas=$(get_service_replicas "$service_name")
    local running_replicas=$(get_running_replicas "$service_name")
    
    echo "Service: $service_name"
    echo "Image: $current_image"
    echo "Replicas: $running_replicas/$desired_replicas"
    echo ""
    
    echo "Task Status:"
    docker service ps "$service_name" --format "table {{.Name}}\t{{.Image}}\t{{.CurrentState}}\t{{.Error}}" | head -10
    echo ""
}

# Rollback function
rollback_service() {
    local service_name="${STACK_NAME}_${SERVICE_NAME}"
    
    log "Initiating service rollback"
    
    docker service rollback \
        --rollback-parallelism "$BATCH_SIZE" \
        --rollback-delay "${BATCH_DELAY}s" \
        --rollback-monitor 60s \
        "$service_name"
    
    if ! monitor_update_progress "$service_name"; then
        error "Rollback failed"
        return 1
    fi
    
    success "Rollback completed successfully"
    display_service_status "$service_name"
}

# Main function
main() {
    case "${1:-}" in
        "update")
            if [[ $# -ne 2 ]]; then
                echo "Usage: $0 update <image>"
                echo "Example: $0 update myapp:v2.0.0"
                exit 1
            fi
            perform_rolling_update "$2"
            ;;
        "rollback")
            rollback_service
            ;;
        "status")
            display_service_status "${STACK_NAME}_${SERVICE_NAME}"
            ;;
        *)
            echo "Usage: $0 {update|rollback|status} [image]"
            echo ""
            echo "Commands:"
            echo "  update <image>  - Perform rolling update to specified image"
            echo "  rollback        - Rollback to previous version"
            echo "  status          - Display current service status"
            echo ""
            echo "Examples:"
            echo "  $0 update myapp:v2.0.0"
            echo "  $0 rollback"
            echo "  $0 status"
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"
```

**Deliverables**:
- [ ] Docker Swarm service configuration with rolling update settings
- [ ] Rolling update controller with monitoring and rollback
- [ ] Health check integration during updates
- [ ] Configurable batch sizes and failure thresholds

---

## Exercise 3: Health Check and Monitoring System 🏥

**Objective**: Create a comprehensive health check and monitoring system for production applications.

### Task 3.1: Multi-Layer Health Check System

```javascript
// comprehensive-health-system.js
const express = require('express');
const prometheus = require('prom-client');
const http = require('http');
const fs = require('fs').promises;

class EnterpriseHealthChecker {
    constructor() {
        this.checks = new Map();
        this.metrics = this.initializeMetrics();
        this.thresholds = {
            memory: 85,
            cpu: 80,
            responseTime: 2000,
            errorRate: 5,
            diskSpace: 90
        };
        this.cache = new Map();
        this.cacheTimeout = 30000; // 30 seconds
        
        this.initializeChecks();
    }
    
    initializeMetrics() {
        return {
            healthCheckDuration: new prometheus.Histogram({
                name: 'health_check_duration_seconds',
                help: 'Duration of health checks in seconds',
                labelNames: ['check_name', 'status']
            }),
            
            healthCheckTotal: new prometheus.Counter({
                name: 'health_checks_total',
                help: 'Total number of health checks performed',
                labelNames: ['check_name', 'status']
            }),
            
            applicationHealth: new prometheus.Gauge({
                name: 'application_health_status',
                help: 'Overall application health status (1=healthy, 0=unhealthy)',
                labelNames: ['component']
            })
        };
    }
    
    initializeChecks() {
        // Infrastructure checks
        this.addCheck('http_server', this.checkHttpServer.bind(this), true);
        this.addCheck('memory_usage', this.checkMemoryUsage.bind(this), true);
        this.addCheck('disk_space', this.checkDiskSpace.bind(this), true);
        
        // Application checks
        this.addCheck('database_connectivity', this.checkDatabase.bind(this), true);
        this.addCheck('external_services', this.checkExternalServices.bind(this), false);
        this.addCheck('cache_system', this.checkCacheSystem.bind(this), false);
        
        // Business logic checks
        this.addCheck('payment_processor', this.checkPaymentProcessor.bind(this), true);
        this.addCheck('user_authentication', this.checkUserAuthentication.bind(this), true);
        this.addCheck('data_integrity', this.checkDataIntegrity.bind(this), false);
    }
    
    addCheck(name, checkFunction, critical = false) {
        this.checks.set(name, { function: checkFunction, critical });
    }
    
    async checkHttpServer() {
        const start = Date.now();
        
        return new Promise((resolve) => {
            const req = http.request({
                hostname: 'localhost',
                port: process.env.PORT || 3000,
                path: '/api/ping',
                method: 'GET',
                timeout: 5000
            }, (res) => {
                const responseTime = Date.now() - start;
                
                if (res.statusCode === 200) {
                    resolve({
                        status: 'healthy',
                        message: 'HTTP server responsive',
                        metrics: { responseTime },
                        timestamp: new Date().toISOString()
                    });
                } else {
                    resolve({
                        status: 'unhealthy',
                        message: `HTTP server returned ${res.statusCode}`,
                        metrics: { responseTime },
                        timestamp: new Date().toISOString()
                    });
                }
            });
            
            req.on('error', (error) => {
                resolve({
                    status: 'unhealthy',
                    message: `HTTP server error: ${error.message}`,
                    timestamp: new Date().toISOString()
                });
            });
            
            req.on('timeout', () => {
                resolve({
                    status: 'unhealthy',
                    message: 'HTTP server timeout',
                    timestamp: new Date().toISOString()
                });
            });
            
            req.end();
        });
    }
    
    async checkMemoryUsage() {
        const memUsage = process.memoryUsage();
        const usagePercent = (memUsage.heapUsed / memUsage.heapTotal) * 100;
        
        let status = 'healthy';
        let message = 'Memory usage normal';
        
        if (usagePercent > this.thresholds.memory) {
            status = 'unhealthy';
            message = `Critical memory usage: ${usagePercent.toFixed(1)}%`;
        } else if (usagePercent > this.thresholds.memory * 0.8) {
            status = 'warning';
            message = `High memory usage: ${usagePercent.toFixed(1)}%`;
        }
        
        return {
            status,
            message,
            metrics: {
                heapUsed: Math.round(memUsage.heapUsed / 1024 / 1024),
                heapTotal: Math.round(memUsage.heapTotal / 1024 / 1024),
                usagePercent: Math.round(usagePercent * 10) / 10,
                external: Math.round(memUsage.external / 1024 / 1024),
                rss: Math.round(memUsage.rss / 1024 / 1024)
            },
            timestamp: new Date().toISOString()
        };
    }
    
    async checkDiskSpace() {
        try {
            // Simulate disk space check
            const diskUsage = Math.random() * 100;
            
            let status = 'healthy';
            let message = 'Disk space sufficient';
            
            if (diskUsage > this.thresholds.diskSpace) {
                status = 'unhealthy';
                message = `Critical disk space usage: ${diskUsage.toFixed(1)}%`;
            } else if (diskUsage > this.thresholds.diskSpace * 0.8) {
                status = 'warning';
                message = `High disk space usage: ${diskUsage.toFixed(1)}%`;
            }
            
            return {
                status,
                message,
                metrics: {
                    usagePercent: Math.round(diskUsage * 10) / 10,
                    availableGB: Math.round((100 - diskUsage) * 10) / 10,
                    totalGB: 100
                },
                timestamp: new Date().toISOString()
            };
        } catch (error) {
            return {
                status: 'unhealthy',
                message: `Disk space check failed: ${error.message}`,
                timestamp: new Date().toISOString()
            };
        }
    }
    
    async checkDatabase() {
        // Simulate database connection check
        const connectionTime = Math.random() * 1000;
        const success = Math.random() > 0.05; // 95% success rate
        
        if (!success) {
            return {
                status: 'unhealthy',
                message: 'Database connection failed',
                metrics: { connectionTime: Math.round(connectionTime) },
                timestamp: new Date().toISOString()
            };
        }
        
        if (connectionTime > 500) {
            return {
                status: 'warning',
                message: 'Database connection slow',
                metrics: { connectionTime: Math.round(connectionTime) },
                timestamp: new Date().toISOString()
            };
        }
        
        return {
            status: 'healthy',
            message: 'Database connection successful',
            metrics: { connectionTime: Math.round(connectionTime) },
            timestamp: new Date().toISOString()
        };
    }
    
    async checkExternalServices() {
        const services = [
            { name: 'payment_gateway', url: 'https://api.payment.com/health', critical: true },
            { name: 'email_service', url: 'https://api.email.com/health', critical: false },
            { name: 'analytics_api', url: 'https://api.analytics.com/health', critical: false }
        ];
        
        const results = [];
        let criticalFailures = 0;
        
        for (const service of services) {
            const isHealthy = Math.random() > 0.1; // 90% success rate
            const responseTime = Math.random() * 2000;
            
            const result = {
                service: service.name,
                status: isHealthy ? 'healthy' : 'unhealthy',
                responseTime: Math.round(responseTime),
                critical: service.critical
            };
            
            results.push(result);
            
            if (!isHealthy && service.critical) {
                criticalFailures++;
            }
        }
        
        return {
            status: criticalFailures > 0 ? 'unhealthy' : 'healthy',
            message: criticalFailures > 0 ? 
                `${criticalFailures} critical external services unavailable` :
                'External services accessible',
            details: results,
            timestamp: new Date().toISOString()
        };
    }
    
    async checkCacheSystem() {
        // Simulate cache system check
        const hitRate = Math.random() * 100;
        const connectionTime = Math.random() * 100;
        
        let status = 'healthy';
        let message = 'Cache system operational';
        
        if (hitRate < 60) {
            status = 'warning';
            message = `Low cache hit rate: ${hitRate.toFixed(1)}%`;
        }
        
        if (connectionTime > 50) {
            status = 'warning';
            message = 'Cache response time elevated';
        }
        
        return {
            status,
            message,
            metrics: {
                hitRate: Math.round(hitRate * 10) / 10,
                connectionTime: Math.round(connectionTime),
                missRate: Math.round((100 - hitRate) * 10) / 10
            },
            timestamp: new Date().toISOString()
        };
    }
    
    async checkPaymentProcessor() {
        // Simulate payment processor health
        const success = Math.random() > 0.02; // 98% success rate
        const processingTime = Math.random() * 3000;
        
        if (!success) {
            return {
                status: 'unhealthy',
                message: 'Payment processor unavailable',
                timestamp: new Date().toISOString()
            };
        }
        
        if (processingTime > 2000) {
            return {
                status: 'warning',
                message: 'Payment processing slow',
                metrics: { processingTime: Math.round(processingTime) },
                timestamp: new Date().toISOString()
            };
        }
        
        return {
            status: 'healthy',
            message: 'Payment processor operational',
            metrics: { processingTime: Math.round(processingTime) },
            timestamp: new Date().toISOString()
        };
    }
    
    async checkUserAuthentication() {
        // Simulate authentication system check
        const authRate = Math.random() * 100;
        const authTime = Math.random() * 1000;
        
        let status = 'healthy';
        let message = 'Authentication system operational';
        
        if (authRate < 95) {
            status = 'warning';
            message = `Authentication success rate: ${authRate.toFixed(1)}%`;
        }
        
        if (authTime > 800) {
            status = 'warning';
            message = 'Authentication response time elevated';
        }
        
        return {
            status,
            message,
            metrics: {
                successRate: Math.round(authRate * 10) / 10,
                responseTime: Math.round(authTime)
            },
            timestamp: new Date().toISOString()
        };
    }
    
    async checkDataIntegrity() {
        // Simulate data integrity check
        const integrityScore = Math.random() * 100;
        
        let status = 'healthy';
        let message = 'Data integrity verified';
        
        if (integrityScore < 99) {
            status = 'warning';
            message = `Data integrity score: ${integrityScore.toFixed(1)}%`;
        }
        
        if (integrityScore < 95) {
            status = 'unhealthy';
            message = `Critical data integrity issues detected: ${integrityScore.toFixed(1)}%`;
        }
        
        return {
            status,
            message,
            metrics: { integrityScore: Math.round(integrityScore * 10) / 10 },
            timestamp: new Date().toISOString()
        };
    }
    
    async runAllChecks() {
        const results = {
            timestamp: new Date().toISOString(),
            overall_status: 'healthy',
            checks: {},
            summary: {
                total: this.checks.size,
                healthy: 0,
                warnings: 0,
                unhealthy: 0,
                critical_failures: 0
            }
        };
        
        for (const [name, { function: checkFunction, critical }] of this.checks) {
            const start = Date.now();
            
            try {
                const result = await checkFunction();
                const duration = (Date.now() - start) / 1000;
                
                results.checks[name] = {
                    ...result,
                    critical,
                    duration
                };
                
                // Update metrics
                this.metrics.healthCheckDuration
                    .labels(name, result.status)
                    .observe(duration);
                
                this.metrics.healthCheckTotal
                    .labels(name, result.status)
                    .inc();
                
                this.metrics.applicationHealth
                    .labels(name)
                    .set(result.status === 'healthy' ? 1 : 0);
                
                // Update summary
                switch (result.status) {
                    case 'healthy':
                        results.summary.healthy++;
                        break;
                    case 'warning':
                        results.summary.warnings++;
                        if (results.overall_status === 'healthy') {
                            results.overall_status = 'warning';
                        }
                        break;
                    case 'unhealthy':
                        results.summary.unhealthy++;
                        results.overall_status = 'unhealthy';
                        if (critical) {
                            results.summary.critical_failures++;
                        }
                        break;
                }
            } catch (error) {
                const duration = (Date.now() - start) / 1000;
                
                results.checks[name] = {
                    status: 'unhealthy',
                    message: `Health check failed: ${error.message}`,
                    critical,
                    duration,
                    timestamp: new Date().toISOString()
                };
                
                results.summary.unhealthy++;
                results.overall_status = 'unhealthy';
                
                if (critical) {
                    results.summary.critical_failures++;
                }
                
                // Update metrics
                this.metrics.healthCheckDuration
                    .labels(name, 'error')
                    .observe(duration);
                
                this.metrics.healthCheckTotal
                    .labels(name, 'error')
                    .inc();
                
                this.metrics.applicationHealth
                    .labels(name)
                    .set(0);
            }
        }
        
        return results;
    }
    
    async getCachedResults() {
        const cacheKey = 'health_check_results';
        const cached = this.cache.get(cacheKey);
        
        if (cached && (Date.now() - cached.timestamp) < this.cacheTimeout) {
            return cached.data;
        }
        
        const results = await this.runAllChecks();
        
        this.cache.set(cacheKey, {
            data: results,
            timestamp: Date.now()
        });
        
        return results;
    }
}

// Express application
const app = express();
const healthChecker = new EnterpriseHealthChecker();

app.use(express.json());

// Health endpoints
app.get('/health', async (req, res) => {
    try {
        const results = await healthChecker.getCachedResults();
        
        const statusCode = results.overall_status === 'unhealthy' ? 503 :
                          results.overall_status === 'warning' ? 200 : 200;
        
        res.status(statusCode).json(results);
    } catch (error) {
        res.status(503).json({
            status: 'unhealthy',
            message: 'Health check system error',
            error: error.message,
            timestamp: new Date().toISOString()
        });
    }
});

app.get('/health/live', (req, res) => {
    res.json({
        status: 'alive',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        pid: process.pid
    });
});

app.get('/health/ready', async (req, res) => {
    try {
        const results = await healthChecker.runAllChecks();
        const criticalFailures = results.summary.critical_failures;
        
        if (criticalFailures > 0) {
            return res.status(503).json({
                status: 'not ready',
                message: `${criticalFailures} critical systems unavailable`,
                timestamp: new Date().toISOString()
            });
        }
        
        res.json({
            status: 'ready',
            timestamp: new Date().toISOString(),
            critical_systems: 'operational'
        });
    } catch (error) {
        res.status(503).json({
            status: 'not ready',
            message: 'Readiness check failed',
            error: error.message,
            timestamp: new Date().toISOString()
        });
    }
});

// Metrics endpoint
app.get('/metrics', async (req, res) => {
    res.set('Content-Type', prometheus.register.contentType);
    res.end(await prometheus.register.metrics());
});

// Simple ping endpoint for basic checks
app.get('/api/ping', (req, res) => {
    res.json({ status: 'pong', timestamp: new Date().toISOString() });
});

// Main application route
app.get('/', (req, res) => {
    res.json({
        message: 'Enterprise Health Check System',
        version: process.env.APP_VERSION || '1.0.0',
        environment: process.env.NODE_ENV || 'development',
        timestamp: new Date().toISOString()
    });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
    console.log(`Health check system listening on port ${PORT}`);
    console.log(`Health endpoint: http://localhost:${PORT}/health`);
    console.log(`Metrics endpoint: http://localhost:${PORT}/metrics`);
});

module.exports = { EnterpriseHealthChecker, app };
```

**Deliverables**:
- [ ] Multi-layer health check system with infrastructure, application, and business logic checks
- [ ] Prometheus metrics integration for health check monitoring
- [ ] Caching mechanism for performance optimization
- [ ] Critical vs non-critical health check classification

---

## 🎯 Module 6 Challenge: Complete Production Deployment Pipeline

**Master Challenge**: Create a complete production deployment pipeline that supports both blue-green and rolling update strategies with comprehensive monitoring.

### Requirements:
1. **Multi-Strategy Deployment System**:
   - Blue-green deployment capability
   - Rolling update deployment capability
   - Canary deployment option
   - A/B testing support

2. **Comprehensive Health Checks**:
   - Infrastructure health monitoring
   - Application health validation
   - Business logic verification
   - External dependency checks

3. **Monitoring and Observability**:
   - Prometheus metrics collection
   - Grafana dashboards
   - Alert management
   - Performance tracking

4. **Automated Operations**:
   - Deployment automation
   - Rollback mechanisms
   - Health-based decisions
   - Failure recovery

5. **Production Readiness**:
   - Load balancer integration
   - SSL/TLS termination
   - Resource management
   - Security controls

### Success Criteria:
- [ ] Zero-downtime deployments achieved
- [ ] Sub-30 second rollback capability
- [ ] 99.9% health check accuracy
- [ ] Complete observability stack
- [ ] Automated failure recovery
- [ ] Load balancer integration working
- [ ] Security controls implemented

**Estimated Time**: 6-8 hours

---

## 📚 Additional Resources

### Deployment Patterns
- **Blue-Green Deployment**: Zero-downtime deployment strategy
- **Rolling Updates**: Gradual deployment with service availability
- **Canary Deployment**: Risk-reduced deployment with gradual rollout
- **A/B Testing**: Feature flag-driven deployments

### Monitoring Tools
- **Prometheus**: Metrics collection and alerting
- **Grafana**: Visualization and dashboards
- **AlertManager**: Alert routing and management
- **Jaeger**: Distributed tracing

### Production Best Practices
- **12-Factor App**: Modern application development principles
- **Site Reliability Engineering**: Google's approach to production systems
- **Chaos Engineering**: Resilience testing in production
- **Observability**: Monitoring, logging, and tracing strategies

This module provides comprehensive coverage of production deployment strategies, ensuring you can deploy and manage containerized applications reliably in enterprise environments.