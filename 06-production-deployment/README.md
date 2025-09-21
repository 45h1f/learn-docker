# Module 6: Production Deployment Strategies

## 🎯 Learning Objectives
- Master production-ready container deployment patterns
- Implement blue-green and rolling deployment strategies
- Design robust health checks and monitoring systems
- Configure enterprise logging and observability
- Optimize resource management and scaling
- Build fault-tolerant and resilient systems

## 📖 Theory: Production Deployment Fundamentals

### Production Deployment Challenges

Deploying containers in production involves multiple critical considerations:

```
┌─────────────────────────────────────────────────────────────┐
│                    High Availability                        │
│  • Zero-downtime deployments • Redundancy                  │
│  • Load balancing • Geographic distribution                 │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│                    Scalability                              │
│  • Horizontal scaling • Auto-scaling                       │
│  • Resource optimization • Performance tuning              │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│                    Reliability                              │
│  • Health checks • Circuit breakers                        │
│  • Graceful degradation • Disaster recovery               │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│                    Observability                           │
│  • Metrics • Logging • Tracing • Alerting                 │
│  • Performance monitoring • Error tracking                 │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│                    Security                                 │
│  • Runtime protection • Access controls                    │
│  • Secret management • Network policies                   │
└─────────────────────────────────────────────────────────────┘
```

### Deployment Patterns

**1. Blue-Green Deployment**
- Two identical production environments
- Switch traffic between versions
- Instant rollback capability
- Zero downtime deployments

**2. Rolling Updates**
- Gradual replacement of instances
- Maintains service availability
- Progressive deployment validation
- Reduced resource requirements

**3. Canary Deployments**
- Limited exposure to new versions
- Risk mitigation through gradual rollout
- Performance and error monitoring
- Automated rollback triggers

**4. A/B Testing**
- Feature flag-driven deployments
- User segment targeting
- Performance comparison
- Data-driven deployment decisions

## 🚀 Blue-Green Deployment Strategy

### Docker Swarm Blue-Green Implementation

```bash
#!/bin/bash
# blue-green-deploy.sh

set -euo pipefail

SERVICE_NAME="web-app"
IMAGE_NAME="myapp"
NEW_VERSION=$1
CURRENT_COLOR=""
NEW_COLOR=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[$(date)] $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Determine current and new colors
determine_colors() {
    if docker service ls | grep -q "${SERVICE_NAME}-blue"; then
        if docker service ps "${SERVICE_NAME}-blue" | grep -q "Running"; then
            CURRENT_COLOR="blue"
            NEW_COLOR="green"
        fi
    fi
    
    if docker service ls | grep -q "${SERVICE_NAME}-green"; then
        if docker service ps "${SERVICE_NAME}-green" | grep -q "Running"; then
            CURRENT_COLOR="green"
            NEW_COLOR="blue"
        fi
    fi
    
    # Default to blue if no service exists
    if [[ -z "$CURRENT_COLOR" ]]; then
        CURRENT_COLOR="none"
        NEW_COLOR="blue"
    fi
    
    print_status "Current environment: $CURRENT_COLOR"
    print_status "Deploying to: $NEW_COLOR"
}

# Health check function
health_check() {
    local service_name=$1
    local max_attempts=30
    local attempt=1
    
    print_status "Performing health check for $service_name..."
    
    while [[ $attempt -le $max_attempts ]]; do
        # Get service endpoint
        local service_ip=$(docker service inspect "$service_name" \
            --format '{{range .Endpoint.VirtualIPs}}{{.Addr}}{{end}}' | cut -d'/' -f1)
        
        if [[ -n "$service_ip" ]]; then
            if curl -f -s "http://$service_ip:8080/health" >/dev/null 2>&1; then
                print_success "Health check passed for $service_name"
                return 0
            fi
        fi
        
        print_warning "Health check attempt $attempt/$max_attempts failed, retrying..."
        sleep 10
        ((attempt++))
    done
    
    print_error "Health check failed for $service_name after $max_attempts attempts"
    return 1
}

# Deploy new version
deploy_new_version() {
    local new_service="${SERVICE_NAME}-${NEW_COLOR}"
    
    print_status "Deploying $new_service with image $IMAGE_NAME:$NEW_VERSION"
    
    # Create or update the new service
    if docker service ls | grep -q "$new_service"; then
        docker service update \
            --image "$IMAGE_NAME:$NEW_VERSION" \
            --update-parallelism 1 \
            --update-delay 10s \
            --update-failure-action rollback \
            "$new_service"
    else
        docker service create \
            --name "$new_service" \
            --replicas 3 \
            --publish 8081:8080 \
            --health-cmd "curl -f http://localhost:8080/health || exit 1" \
            --health-interval 30s \
            --health-timeout 10s \
            --health-retries 3 \
            --update-parallelism 1 \
            --update-delay 10s \
            --update-failure-action rollback \
            --restart-condition on-failure \
            --restart-delay 5s \
            --restart-max-attempts 3 \
            --constraint 'node.role==worker' \
            "$IMAGE_NAME:$NEW_VERSION"
    fi
    
    print_success "Service $new_service deployed"
}

# Switch traffic
switch_traffic() {
    local old_service="${SERVICE_NAME}-${CURRENT_COLOR}"
    local new_service="${SERVICE_NAME}-${NEW_COLOR}"
    
    print_status "Switching traffic from $old_service to $new_service"
    
    # Update load balancer or ingress (simulation)
    print_status "Updating load balancer configuration..."
    
    # In real implementation, this would update:
    # - Load balancer targets
    # - Ingress controller rules
    # - DNS records
    # - Service mesh routing
    
    # For demo, we'll update port mapping
    if [[ "$CURRENT_COLOR" != "none" ]]; then
        # Remove port from old service
        docker service update --publish-rm 8080:8080 "$old_service" 2>/dev/null || true
    fi
    
    # Add port to new service
    docker service update --publish-add 8080:8080 "$new_service"
    
    print_success "Traffic switched to $new_service"
}

# Rollback function
rollback() {
    local old_service="${SERVICE_NAME}-${CURRENT_COLOR}"
    local new_service="${SERVICE_NAME}-${NEW_COLOR}"
    
    print_error "Rolling back deployment"
    
    # Switch traffic back
    docker service update --publish-rm 8080:8080 "$new_service" 2>/dev/null || true
    if [[ "$CURRENT_COLOR" != "none" ]]; then
        docker service update --publish-add 8080:8080 "$old_service"
    fi
    
    # Remove failed service
    docker service rm "$new_service" 2>/dev/null || true
    
    print_success "Rollback completed"
}

# Cleanup old version
cleanup_old_version() {
    if [[ "$CURRENT_COLOR" != "none" ]]; then
        local old_service="${SERVICE_NAME}-${CURRENT_COLOR}"
        print_status "Cleaning up old service: $old_service"
        
        # Wait a bit before cleanup to ensure traffic has switched
        sleep 30
        
        docker service rm "$old_service"
        print_success "Old service $old_service removed"
    fi
}

# Main deployment process
main() {
    if [[ $# -ne 1 ]]; then
        echo "Usage: $0 <new_version>"
        echo "Example: $0 v2.1.0"
        exit 1
    fi
    
    print_status "Starting blue-green deployment for $SERVICE_NAME:$NEW_VERSION"
    
    # Determine current state
    determine_colors
    
    # Deploy new version
    deploy_new_version
    
    # Health check new version
    if ! health_check "${SERVICE_NAME}-${NEW_COLOR}"; then
        rollback
        exit 1
    fi
    
    # Switch traffic
    switch_traffic
    
    # Final health check
    print_status "Performing final health check..."
    sleep 30
    if ! health_check "${SERVICE_NAME}-${NEW_COLOR}"; then
        rollback
        exit 1
    fi
    
    # Cleanup old version
    cleanup_old_version
    
    print_success "Blue-green deployment completed successfully!"
    print_status "Service $SERVICE_NAME is now running version $NEW_VERSION on $NEW_COLOR environment"
}

# Execute main function
main "$@"
```

### Load Balancer Configuration

```yaml
# nginx-load-balancer.yml
version: '3.8'

services:
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/ssl/certs:ro
    networks:
      - frontend
      - backend
    deploy:
      replicas: 2
      placement:
        constraints:
          - node.role == manager
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3

  web-app-blue:
    image: myapp:${BLUE_VERSION:-latest}
    networks:
      - backend
    deploy:
      replicas: 3
      placement:
        constraints:
          - node.role == worker
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 256M
      restart_policy:
        condition: on-failure
      update_config:
        parallelism: 1
        delay: 10s
        failure_action: rollback
      rollback_config:
        parallelism: 1
        delay: 10s

  web-app-green:
    image: myapp:${GREEN_VERSION:-latest}
    networks:
      - backend
    deploy:
      replicas: 3
      placement:
        constraints:
          - node.role == worker
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 256M
      restart_policy:
        condition: on-failure

networks:
  frontend:
    driver: overlay
  backend:
    driver: overlay
    internal: true
```

**NGINX Configuration for Blue-Green:**
```nginx
# nginx.conf
events {
    worker_connections 1024;
}

http {
    upstream backend {
        least_conn;
        
        # Blue environment (default)
        server web-app-blue:8080 max_fails=3 fail_timeout=30s;
        
        # Green environment (commented out initially)
        # server web-app-green:8080 max_fails=3 fail_timeout=30s;
    }
    
    # Health check endpoint
    upstream health_check {
        server web-app-blue:8080;
        # server web-app-green:8080;
    }
    
    server {
        listen 80;
        
        # Health check endpoint
        location /health {
            proxy_pass http://health_check/health;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            access_log off;
        }
        
        # Main application
        location / {
            proxy_pass http://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # Connection settings
            proxy_connect_timeout 30s;
            proxy_send_timeout 30s;
            proxy_read_timeout 30s;
            
            # Retry logic
            proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;
            proxy_next_upstream_tries 3;
            proxy_next_upstream_timeout 30s;
        }
    }
    
    # Status endpoint for monitoring
    server {
        listen 8080;
        location /nginx-status {
            stub_status on;
            access_log off;
            allow 172.16.0.0/12;
            deny all;
        }
    }
}
```

## 🔄 Rolling Update Strategy

### Docker Swarm Rolling Updates

```bash
#!/bin/bash
# rolling-update.sh

set -euo pipefail

SERVICE_NAME=$1
NEW_VERSION=$2
PARALLELISM=${3:-2}
DELAY=${4:-30s}

print_status() {
    echo "[$(date)] $1"
}

# Pre-deployment validation
validate_image() {
    local image="$1"
    print_status "Validating image: $image"
    
    if ! docker pull "$image"; then
        echo "❌ Failed to pull image: $image"
        exit 1
    fi
    
    # Basic security scan
    if command -v docker scout >/dev/null 2>&1; then
        print_status "Running security scan..."
        docker scout cves "$image" --exit-code || {
            echo "⚠️  Security vulnerabilities found in $image"
            read -p "Continue with deployment? (y/N): " -n 1 -r
            echo
            [[ $REPLY =~ ^[Yy]$ ]] || exit 1
        }
    fi
    
    echo "✅ Image validation passed"
}

# Rolling update with monitoring
perform_rolling_update() {
    print_status "Starting rolling update for $SERVICE_NAME to $NEW_VERSION"
    
    # Get current service configuration
    local current_image=$(docker service inspect "$SERVICE_NAME" \
        --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}')
    
    print_status "Current image: $current_image"
    print_status "Target image: $NEW_VERSION"
    
    # Configure update settings
    docker service update \
        --image "$NEW_VERSION" \
        --update-parallelism "$PARALLELISM" \
        --update-delay "$DELAY" \
        --update-monitor 60s \
        --update-failure-action rollback \
        --update-max-failure-ratio 0.2 \
        --rollback-parallelism "$PARALLELISM" \
        --rollback-delay "$DELAY" \
        --rollback-monitor 60s \
        --rollback-failure-action pause \
        --rollback-max-failure-ratio 0.2 \
        "$SERVICE_NAME"
    
    print_status "Rolling update initiated"
}

# Monitor update progress
monitor_update() {
    local service_name="$1"
    local max_wait=600  # 10 minutes
    local elapsed=0
    
    print_status "Monitoring update progress..."
    
    while [[ $elapsed -lt $max_wait ]]; do
        local update_status=$(docker service inspect "$service_name" \
            --format '{{.UpdateStatus.State}}' 2>/dev/null || echo "unknown")
        
        case "$update_status" in
            "completed")
                echo "✅ Rolling update completed successfully"
                return 0
                ;;
            "rollback_completed")
                echo "❌ Rolling update failed, rollback completed"
                return 1
                ;;
            "paused")
                echo "⚠️  Rolling update paused due to failures"
                return 1
                ;;
            "updating"|"rollback_started")
                local running_tasks=$(docker service ps "$service_name" \
                    --format "table {{.CurrentState}}" | grep -c "Running" || echo "0")
                local total_tasks=$(docker service inspect "$service_name" \
                    --format '{{.Spec.Mode.Replicated.Replicas}}')
                
                print_status "Update in progress... ($running_tasks/$total_tasks tasks running)"
                ;;
        esac
        
        sleep 30
        elapsed=$((elapsed + 30))
    done
    
    echo "❌ Update monitoring timeout reached"
    return 1
}

# Health validation
validate_deployment() {
    local service_name="$1"
    print_status "Validating deployment health..."
    
    # Check all replicas are running
    local desired_replicas=$(docker service inspect "$service_name" \
        --format '{{.Spec.Mode.Replicated.Replicas}}')
    local running_replicas=$(docker service ps "$service_name" \
        --filter "desired-state=running" --format "{{.CurrentState}}" | grep -c "Running" || echo "0")
    
    if [[ "$running_replicas" -ne "$desired_replicas" ]]; then
        echo "❌ Not all replicas are running ($running_replicas/$desired_replicas)"
        return 1
    fi
    
    # Application-specific health checks
    if command -v curl >/dev/null 2>&1; then
        local service_endpoint=$(docker service inspect "$service_name" \
            --format '{{range .Endpoint.Ports}}{{if eq .TargetPort 8080}}localhost:{{.PublishedPort}}{{end}}{{end}}')
        
        if [[ -n "$service_endpoint" ]]; then
            print_status "Testing application endpoint: $service_endpoint"
            
            local attempt=1
            local max_attempts=10
            
            while [[ $attempt -le $max_attempts ]]; do
                if curl -f -s "http://$service_endpoint/health" >/dev/null; then
                    echo "✅ Application health check passed"
                    return 0
                fi
                
                print_status "Health check attempt $attempt/$max_attempts failed, retrying..."
                sleep 10
                ((attempt++))
            done
            
            echo "❌ Application health check failed"
            return 1
        fi
    fi
    
    echo "✅ Deployment validation passed"
    return 0
}

# Main function
main() {
    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 <service_name> <new_version> [parallelism] [delay]"
        echo "Example: $0 web-app myapp:v2.0.0 2 30s"
        exit 1
    fi
    
    # Validate inputs
    if ! docker service ls | grep -q "^$SERVICE_NAME"; then
        echo "❌ Service $SERVICE_NAME not found"
        exit 1
    fi
    
    # Validate new image
    validate_image "$NEW_VERSION"
    
    # Perform rolling update
    perform_rolling_update
    
    # Monitor progress
    if ! monitor_update "$SERVICE_NAME"; then
        echo "❌ Rolling update failed"
        exit 1
    fi
    
    # Validate final deployment
    if ! validate_deployment "$SERVICE_NAME"; then
        echo "❌ Deployment validation failed"
        exit 1
    fi
    
    echo "🎉 Rolling update completed successfully!"
    
    # Display final status
    echo ""
    echo "Service Status:"
    docker service ps "$SERVICE_NAME" --format "table {{.Name}}\t{{.Image}}\t{{.CurrentState}}\t{{.Error}}"
}

# Execute main function
main "$@"
```

## 🏥 Health Checks and Monitoring

### Comprehensive Health Check Implementation

```dockerfile
# Health check enabled Dockerfile
FROM node:16-alpine AS base

# Install health check dependencies
RUN apk add --no-cache curl dumb-init

FROM base AS production

WORKDIR /app

# Create non-root user
RUN addgroup -g 1001 -S appgroup && \
    adduser -S -u 1001 -h /app -G appgroup appuser

# Copy application
COPY --chown=appuser:appgroup package*.json ./
RUN npm ci --only=production && npm cache clean --force

COPY --chown=appuser:appgroup . .

USER appuser

# Comprehensive health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD node healthcheck.js || exit 1

EXPOSE 3000

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["node", "server.js"]
```

**Advanced Health Check Script:**
```javascript
// healthcheck.js
const http = require('http');
const fs = require('fs').promises;

class HealthChecker {
    constructor() {
        this.checks = [];
        this.addDefaultChecks();
    }
    
    addDefaultChecks() {
        // HTTP endpoint check
        this.addCheck('http', this.checkHttpEndpoint.bind(this));
        
        // Database connectivity check
        this.addCheck('database', this.checkDatabase.bind(this));
        
        // External services check
        this.addCheck('external_apis', this.checkExternalAPIs.bind(this));
        
        // Resource availability check
        this.addCheck('resources', this.checkResources.bind(this));
        
        // Application-specific checks
        this.addCheck('business_logic', this.checkBusinessLogic.bind(this));
    }
    
    addCheck(name, checkFunction) {
        this.checks.push({ name, check: checkFunction });
    }
    
    async checkHttpEndpoint() {
        return new Promise((resolve) => {
            const req = http.request({
                hostname: 'localhost',
                port: 3000,
                path: '/api/status',
                method: 'GET',
                timeout: 5000
            }, (res) => {
                if (res.statusCode === 200) {
                    resolve({ status: 'healthy', message: 'HTTP endpoint responsive' });
                } else {
                    resolve({ status: 'unhealthy', message: `HTTP endpoint returned ${res.statusCode}` });
                }
            });
            
            req.on('error', (error) => {
                resolve({ status: 'unhealthy', message: `HTTP check failed: ${error.message}` });
            });
            
            req.on('timeout', () => {
                resolve({ status: 'unhealthy', message: 'HTTP endpoint timeout' });
            });
            
            req.end();
        });
    }
    
    async checkDatabase() {
        try {
            // Simulate database connection check
            const dbConfig = process.env.DATABASE_URL;
            if (!dbConfig) {
                return { status: 'warning', message: 'Database configuration missing' };
            }
            
            // In real implementation, test actual database connection
            // const db = await connectToDatabase();
            // await db.query('SELECT 1');
            
            return { status: 'healthy', message: 'Database connection successful' };
        } catch (error) {
            return { status: 'unhealthy', message: `Database check failed: ${error.message}` };
        }
    }
    
    async checkExternalAPIs() {
        const externalServices = [
            { name: 'payment_api', url: process.env.PAYMENT_API_URL },
            { name: 'auth_service', url: process.env.AUTH_SERVICE_URL }
        ];
        
        const results = [];
        
        for (const service of externalServices) {
            if (!service.url) {
                results.push({
                    service: service.name,
                    status: 'warning',
                    message: 'Service URL not configured'
                });
                continue;
            }
            
            try {
                // Simulate external API check
                const response = await this.httpRequest(service.url + '/health');
                results.push({
                    service: service.name,
                    status: response.status === 200 ? 'healthy' : 'unhealthy',
                    message: `Response: ${response.status}`
                });
            } catch (error) {
                results.push({
                    service: service.name,
                    status: 'unhealthy',
                    message: error.message
                });
            }
        }
        
        const unhealthy = results.filter(r => r.status === 'unhealthy');
        if (unhealthy.length > 0) {
            return { status: 'unhealthy', message: 'External services unavailable', details: results };
        }
        
        return { status: 'healthy', message: 'External services accessible', details: results };
    }
    
    async checkResources() {
        try {
            // Check disk space
            const stats = await fs.stat('/tmp');
            
            // Check memory usage (simplified)
            const memInfo = process.memoryUsage();
            const memUsagePercent = (memInfo.heapUsed / memInfo.heapTotal) * 100;
            
            if (memUsagePercent > 90) {
                return { status: 'unhealthy', message: `High memory usage: ${memUsagePercent.toFixed(1)}%` };
            }
            
            if (memUsagePercent > 80) {
                return { status: 'warning', message: `Memory usage: ${memUsagePercent.toFixed(1)}%` };
            }
            
            return { 
                status: 'healthy', 
                message: 'Resource usage normal',
                details: {
                    memory_usage_percent: memUsagePercent.toFixed(1),
                    heap_used_mb: (memInfo.heapUsed / 1024 / 1024).toFixed(1),
                    heap_total_mb: (memInfo.heapTotal / 1024 / 1024).toFixed(1)
                }
            };
        } catch (error) {
            return { status: 'unhealthy', message: `Resource check failed: ${error.message}` };
        }
    }
    
    async checkBusinessLogic() {
        try {
            // Application-specific business logic checks
            const criticalFeatures = [
                'user_authentication',
                'payment_processing',
                'data_validation',
                'security_middleware'
            ];
            
            // Simulate feature availability checks
            for (const feature of criticalFeatures) {
                // In real implementation, test actual feature functionality
                const isAvailable = Math.random() > 0.1; // 90% success rate simulation
                
                if (!isAvailable) {
                    return { 
                        status: 'unhealthy', 
                        message: `Critical feature unavailable: ${feature}` 
                    };
                }
            }
            
            return { status: 'healthy', message: 'All critical features operational' };
        } catch (error) {
            return { status: 'unhealthy', message: `Business logic check failed: ${error.message}` };
        }
    }
    
    async httpRequest(url) {
        // Simplified HTTP request implementation
        return new Promise((resolve, reject) => {
            const urlObj = new URL(url);
            const req = http.request({
                hostname: urlObj.hostname,
                port: urlObj.port || 80,
                path: urlObj.pathname,
                method: 'GET',
                timeout: 5000
            }, (res) => {
                resolve({ status: res.statusCode });
            });
            
            req.on('error', reject);
            req.on('timeout', () => reject(new Error('Request timeout')));
            req.end();
        });
    }
    
    async runAllChecks() {
        const results = {
            timestamp: new Date().toISOString(),
            overall_status: 'healthy',
            checks: {}
        };
        
        for (const { name, check } of this.checks) {
            try {
                const result = await check();
                results.checks[name] = result;
                
                if (result.status === 'unhealthy') {
                    results.overall_status = 'unhealthy';
                } else if (result.status === 'warning' && results.overall_status === 'healthy') {
                    results.overall_status = 'warning';
                }
            } catch (error) {
                results.checks[name] = {
                    status: 'unhealthy',
                    message: `Check failed: ${error.message}`
                };
                results.overall_status = 'unhealthy';
            }
        }
        
        return results;
    }
}

// Main health check execution
async function main() {
    const checker = new HealthChecker();
    const results = await checker.runAllChecks();
    
    // Output results for Docker health check
    console.log(JSON.stringify(results, null, 2));
    
    // Exit with appropriate code
    if (results.overall_status === 'unhealthy') {
        process.exit(1);
    } else if (results.overall_status === 'warning') {
        // Consider warnings as healthy for Docker health check
        // but log the warnings
        console.warn('Health check passed with warnings');
        process.exit(0);
    } else {
        process.exit(0);
    }
}

// Run health check if this file is executed directly
if (require.main === module) {
    main().catch(error => {
        console.error('Health check failed:', error);
        process.exit(1);
    });
}

module.exports = HealthChecker;
```

### Service Monitoring with Prometheus

```yaml
# monitoring-stack.yml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
      - '--web.enable-lifecycle'
      - '--web.enable-admin-api'
    networks:
      - monitoring
    deploy:
      placement:
        constraints:
          - node.role == manager

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin123
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/dashboards:/etc/grafana/provisioning/dashboards:ro
      - ./grafana/datasources:/etc/grafana/provisioning/datasources:ro
    networks:
      - monitoring
    deploy:
      placement:
        constraints:
          - node.role == manager

  node-exporter:
    image: prom/node-exporter:latest
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.ignored-mount-points=^/(sys|proc|dev|host|etc)($$|/)'
    networks:
      - monitoring
    deploy:
      mode: global

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    ports:
      - "8080:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:rw
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
    networks:
      - monitoring
    deploy:
      mode: global

  alertmanager:
    image: prom/alertmanager:latest
    ports:
      - "9093:9093"
    volumes:
      - ./alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro
      - alertmanager_data:/alertmanager
    networks:
      - monitoring
    deploy:
      placement:
        constraints:
          - node.role == manager

volumes:
  prometheus_data:
  grafana_data:
  alertmanager_data:

networks:
  monitoring:
    driver: overlay
```

This module provides comprehensive coverage of production deployment strategies, ensuring you can deploy containers reliably and safely in enterprise environments with proper monitoring and rollback capabilities.