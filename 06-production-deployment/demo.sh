#!/bin/bash
# Module 6: Production Deployment Strategies - Demo Script

set -e

echo "🚀 MODULE 6: PRODUCTION DEPLOYMENT STRATEGIES DEMO"
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
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

# Demo 1: Production-Ready Application
print_header "Demo 1: Building Production-Ready Application"

echo "Creating production-ready application with health checks..."
cat > production-app.js << 'EOF'
const express = require('express');
const prometheus = require('prom-client');

const app = express();
const PORT = process.env.PORT || 3000;

// Prometheus metrics
const httpRequestDuration = new prometheus.Histogram({
    name: 'http_request_duration_seconds',
    help: 'Duration of HTTP requests in seconds',
    labelNames: ['method', 'route', 'status_code'],
    buckets: [0.1, 0.5, 1, 2, 5]
});

const httpRequestTotal = new prometheus.Counter({
    name: 'http_requests_total',
    help: 'Total number of HTTP requests',
    labelNames: ['method', 'route', 'status_code']
});

const appUptime = new prometheus.Gauge({
    name: 'app_uptime_seconds',
    help: 'Application uptime in seconds'
});

// Start time for uptime calculation
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
        
        httpRequestTotal
            .labels(req.method, route, res.statusCode)
            .inc();
        
        appUptime.set((Date.now() - startTime) / 1000);
    });
    
    next();
});

// Health check endpoint
app.get('/health', (req, res) => {
    const healthStatus = {
        status: 'healthy',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        memory: process.memoryUsage(),
        environment: process.env.NODE_ENV || 'development',
        version: process.env.APP_VERSION || '1.0.0'
    };
    
    // Simple health checks
    const memoryUsage = process.memoryUsage().heapUsed / process.memoryUsage().heapTotal;
    if (memoryUsage > 0.9) {
        healthStatus.status = 'unhealthy';
        healthStatus.reason = 'High memory usage';
        return res.status(503).json(healthStatus);
    }
    
    res.json(healthStatus);
});

// Readiness check endpoint
app.get('/ready', (req, res) => {
    // Check if application is ready to serve traffic
    const readinessStatus = {
        status: 'ready',
        timestamp: new Date().toISOString(),
        checks: {
            database: 'connected',
            external_apis: 'available',
            cache: 'operational'
        }
    };
    
    res.json(readinessStatus);
});

// Liveness check endpoint
app.get('/live', (req, res) => {
    res.json({
        status: 'alive',
        timestamp: new Date().toISOString(),
        pid: process.pid
    });
});

// Metrics endpoint for Prometheus
app.get('/metrics', async (req, res) => {
    res.set('Content-Type', prometheus.register.contentType);
    res.end(await prometheus.register.metrics());
});

// Main application routes
app.get('/', (req, res) => {
    res.json({
        message: 'Production-Ready Application',
        version: process.env.APP_VERSION || '1.0.0',
        environment: process.env.NODE_ENV || 'development',
        timestamp: new Date().toISOString()
    });
});

app.get('/api/status', (req, res) => {
    res.json({
        status: 'operational',
        services: {
            web: 'running',
            database: 'connected',
            cache: 'available'
        },
        timestamp: new Date().toISOString()
    });
});

// Error handling middleware
app.use((err, req, res, next) => {
    console.error('Unhandled error:', err);
    res.status(500).json({
        error: 'Internal server error',
        timestamp: new Date().toISOString()
    });
});

// Graceful shutdown handling
process.on('SIGTERM', () => {
    console.log('SIGTERM received, shutting down gracefully');
    process.exit(0);
});

process.on('SIGINT', () => {
    console.log('SIGINT received, shutting down gracefully');
    process.exit(0);
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`Production app listening on port ${PORT}`);
    console.log(`Health check: http://localhost:${PORT}/health`);
    console.log(`Metrics: http://localhost:${PORT}/metrics`);
});
EOF

cat > package.json << 'EOF'
{
  "name": "production-app",
  "version": "1.0.0",
  "description": "Production-ready application with health checks and metrics",
  "main": "production-app.js",
  "scripts": {
    "start": "node production-app.js",
    "test": "echo \"Tests would go here\" && exit 0"
  },
  "dependencies": {
    "express": "^4.18.2",
    "prom-client": "^14.2.0"
  }
}
EOF

echo "Creating production Dockerfile..."
cat > Dockerfile.production << 'EOF'
# Multi-stage production build
FROM node:18-alpine AS base
RUN apk add --no-cache dumb-init curl
WORKDIR /app

FROM base AS deps
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

FROM base AS production
# Create non-root user
RUN addgroup -g 1001 -S appgroup && \
    adduser -S -u 1001 -h /app -G appgroup appuser

# Copy dependencies and application
COPY --from=deps --chown=appuser:appgroup /app/node_modules ./node_modules
COPY --chown=appuser:appgroup production-app.js ./

USER appuser

# Health checks
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

EXPOSE 3000

# Use dumb-init for proper signal handling
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["node", "production-app.js"]
EOF

print_success "Created production-ready application with health checks and metrics"

# Build the production image
echo "Building production image..."
if docker build -f Dockerfile.production -t production-app:v1.0.0 . 2>/dev/null; then
    print_success "Production image built successfully"
else
    print_warning "Docker not available - showing example output"
fi

# Demo 2: Blue-Green Deployment Simulation
print_header "Demo 2: Blue-Green Deployment Strategy"

echo "Creating blue-green deployment simulation..."
cat > blue-green-demo.sh << 'EOF'
#!/bin/bash
# Blue-Green Deployment Simulation

set -euo pipefail

# Configuration
SERVICE_NAME="production-app"
BLUE_PORT=8080
GREEN_PORT=8081
HEALTH_CHECK_URL="/health"

# Colors
BLUE_COLOR='\033[0;34m'
GREEN_COLOR='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_blue() {
    echo -e "${BLUE_COLOR}🔵 BLUE: $1${NC}"
}

print_green() {
    echo -e "${GREEN_COLOR}🟢 GREEN: $1${NC}"
}

print_status() {
    echo -e "${YELLOW}📊 STATUS: $1${NC}"
}

# Current state tracking
CURRENT_ENV=""
TARGET_ENV=""
LOAD_BALANCER_TARGET=""

determine_current_state() {
    print_status "Determining current deployment state..."
    
    # Check which environment is currently serving traffic
    if curl -s http://localhost:$BLUE_PORT$HEALTH_CHECK_URL >/dev/null 2>&1; then
        if [[ $(curl -s http://localhost:80 2>/dev/null || echo "none") != "none" ]]; then
            # Check if load balancer points to blue
            CURRENT_ENV="blue"
            TARGET_ENV="green"
            LOAD_BALANCER_TARGET="blue"
        else
            CURRENT_ENV="none"
            TARGET_ENV="blue"
        fi
    elif curl -s http://localhost:$GREEN_PORT$HEALTH_CHECK_URL >/dev/null 2>&1; then
        CURRENT_ENV="green"
        TARGET_ENV="blue"
        LOAD_BALANCER_TARGET="green"
    else
        CURRENT_ENV="none"
        TARGET_ENV="blue"
    fi
    
    print_status "Current environment: $CURRENT_ENV"
    print_status "Target environment: $TARGET_ENV"
}

deploy_to_target() {
    local version=$1
    local target_port=""
    
    if [[ "$TARGET_ENV" == "blue" ]]; then
        target_port=$BLUE_PORT
        print_blue "Deploying version $version to blue environment (port $target_port)"
    else
        target_port=$GREEN_PORT
        print_green "Deploying version $version to green environment (port $target_port)"
    fi
    
    # Stop existing container in target environment
    docker stop "${SERVICE_NAME}-${TARGET_ENV}" 2>/dev/null || true
    docker rm "${SERVICE_NAME}-${TARGET_ENV}" 2>/dev/null || true
    
    # Deploy new version to target environment
    docker run -d \
        --name "${SERVICE_NAME}-${TARGET_ENV}" \
        --publish "$target_port:3000" \
        --env NODE_ENV=production \
        --env APP_VERSION="$version" \
        --restart unless-stopped \
        production-app:$version 2>/dev/null || {
        
        # Fallback for demo when Docker is not available
        echo "Docker not available - simulating deployment"
        echo "Would deploy: ${SERVICE_NAME}-${TARGET_ENV} on port $target_port"
    }
    
    if [[ "$TARGET_ENV" == "blue" ]]; then
        print_blue "Blue environment deployment initiated"
    else
        print_green "Green environment deployment initiated"
    fi
}

health_check_target() {
    local target_port=""
    local max_attempts=10
    local attempt=1
    
    if [[ "$TARGET_ENV" == "blue" ]]; then
        target_port=$BLUE_PORT
        print_blue "Performing health check on blue environment"
    else
        target_port=$GREEN_PORT
        print_green "Performing health check on green environment"
    fi
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -f -s "http://localhost:$target_port$HEALTH_CHECK_URL" >/dev/null 2>&1; then
            if [[ "$TARGET_ENV" == "blue" ]]; then
                print_blue "Health check passed ✅"
            else
                print_green "Health check passed ✅"
            fi
            return 0
        fi
        
        print_status "Health check attempt $attempt/$max_attempts - waiting..."
        sleep 5
        ((attempt++))
    done
    
    if [[ "$TARGET_ENV" == "blue" ]]; then
        print_blue "Health check failed ❌"
    else
        print_green "Health check failed ❌"
    fi
    return 1
}

switch_traffic() {
    print_status "Switching traffic to $TARGET_ENV environment"
    
    # Simulate load balancer traffic switch
    echo "# Load Balancer Configuration Update" > load-balancer-config.txt
    echo "upstream backend {" >> load-balancer-config.txt
    
    if [[ "$TARGET_ENV" == "blue" ]]; then
        echo "    server localhost:$BLUE_PORT;" >> load-balancer-config.txt
        print_blue "Traffic switched to blue environment"
    else
        echo "    server localhost:$GREEN_PORT;" >> load-balancer-config.txt
        print_green "Traffic switched to green environment"
    fi
    
    echo "}" >> load-balancer-config.txt
    
    print_status "Load balancer updated to route traffic to $TARGET_ENV"
    LOAD_BALANCER_TARGET="$TARGET_ENV"
}

cleanup_old_environment() {
    if [[ "$CURRENT_ENV" != "none" ]] && [[ "$CURRENT_ENV" != "$TARGET_ENV" ]]; then
        print_status "Cleaning up old $CURRENT_ENV environment"
        
        # Wait before cleanup to ensure traffic has switched
        sleep 10
        
        docker stop "${SERVICE_NAME}-${CURRENT_ENV}" 2>/dev/null || true
        docker rm "${SERVICE_NAME}-${CURRENT_ENV}" 2>/dev/null || true
        
        if [[ "$CURRENT_ENV" == "blue" ]]; then
            print_blue "Blue environment cleaned up"
        else
            print_green "Green environment cleaned up"
        fi
    fi
}

rollback() {
    print_status "Rolling back deployment"
    
    if [[ "$CURRENT_ENV" != "none" ]]; then
        # Switch traffic back to previous environment
        if [[ "$CURRENT_ENV" == "blue" ]]; then
            print_blue "Rolling back to blue environment"
        else
            print_green "Rolling back to green environment"
        fi
        
        # Update load balancer back to current environment
        LOAD_BALANCER_TARGET="$CURRENT_ENV"
        print_status "Traffic rolled back to $CURRENT_ENV environment"
    fi
    
    # Remove failed deployment
    docker stop "${SERVICE_NAME}-${TARGET_ENV}" 2>/dev/null || true
    docker rm "${SERVICE_NAME}-${TARGET_ENV}" 2>/dev/null || true
}

# Main blue-green deployment function
blue_green_deploy() {
    local new_version=$1
    
    echo "🚀 Starting Blue-Green Deployment"
    echo "================================="
    echo "Deploying version: $new_version"
    echo ""
    
    # Step 1: Determine current state
    determine_current_state
    echo ""
    
    # Step 2: Deploy to target environment
    deploy_to_target "$new_version"
    echo ""
    
    # Step 3: Health check target environment
    if ! health_check_target; then
        echo ""
        echo "❌ Health check failed - initiating rollback"
        rollback
        return 1
    fi
    echo ""
    
    # Step 4: Switch traffic
    switch_traffic
    echo ""
    
    # Step 5: Final verification
    print_status "Performing final verification..."
    sleep 5
    
    if [[ "$TARGET_ENV" == "blue" ]]; then
        print_blue "Final verification passed"
    else
        print_green "Final verification passed"
    fi
    echo ""
    
    # Step 6: Cleanup old environment
    cleanup_old_environment
    echo ""
    
    echo "🎉 Blue-Green deployment completed successfully!"
    echo "Active environment: $TARGET_ENV"
    echo "Version deployed: $new_version"
}

# Demo execution
echo "Blue-Green Deployment Demo"
echo "========================="

# Simulate multiple deployments
blue_green_deploy "v1.0.0"
echo ""
echo "Waiting 10 seconds before next deployment..."
sleep 5  # Reduced for demo

blue_green_deploy "v1.1.0"
echo ""
echo "Waiting 10 seconds before next deployment..."
sleep 5  # Reduced for demo

blue_green_deploy "v1.2.0"

echo ""
echo "Blue-Green deployment demonstration completed!"
EOF

chmod +x blue-green-demo.sh
./blue-green-demo.sh

print_success "Blue-Green deployment demonstration completed"

# Demo 3: Rolling Update Strategy
print_header "Demo 3: Rolling Update Strategy"

echo "Creating rolling update simulation..."
cat > rolling-update-demo.sh << 'EOF'
#!/bin/bash
# Rolling Update Simulation

set -euo pipefail

SERVICE_NAME="web-service"
CURRENT_VERSION="v1.0.0"
NEW_VERSION="v2.0.0"
TOTAL_INSTANCES=6
BATCH_SIZE=2
DELAY_BETWEEN_BATCHES=10

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${YELLOW}📊 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Instance tracking
declare -a INSTANCES
declare -a INSTANCE_VERSIONS
declare -a INSTANCE_STATUS

# Initialize instances
initialize_instances() {
    print_status "Initializing $TOTAL_INSTANCES instances of $SERVICE_NAME"
    
    for i in $(seq 1 $TOTAL_INSTANCES); do
        INSTANCES[$i]="${SERVICE_NAME}-instance-$i"
        INSTANCE_VERSIONS[$i]="$CURRENT_VERSION"
        INSTANCE_STATUS[$i]="running"
    done
    
    display_service_status
}

display_service_status() {
    echo ""
    echo "Service Status Dashboard"
    echo "======================="
    printf "%-20s %-10s %-10s\n" "Instance" "Version" "Status"
    echo "---------------------------------------"
    
    for i in $(seq 1 $TOTAL_INSTANCES); do
        local status_icon="🟢"
        if [[ "${INSTANCE_STATUS[$i]}" == "updating" ]]; then
            status_icon="🟡"
        elif [[ "${INSTANCE_STATUS[$i]}" == "stopped" ]]; then
            status_icon="🔴"
        fi
        
        printf "%-20s %-10s %-10s %s\n" \
            "${INSTANCES[$i]}" \
            "${INSTANCE_VERSIONS[$i]}" \
            "${INSTANCE_STATUS[$i]}" \
            "$status_icon"
    done
    echo ""
}

health_check_instance() {
    local instance_id=$1
    local max_attempts=5
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        # Simulate health check (90% success rate)
        if [[ $(( RANDOM % 10 )) -lt 9 ]]; then
            return 0
        fi
        
        print_status "Health check attempt $attempt/$max_attempts for ${INSTANCES[$instance_id]}"
        sleep 2
        ((attempt++))
    done
    
    return 1
}

update_instance() {
    local instance_id=$1
    
    print_status "Updating ${INSTANCES[$instance_id]} from ${INSTANCE_VERSIONS[$instance_id]} to $NEW_VERSION"
    
    # Step 1: Stop instance
    INSTANCE_STATUS[$instance_id]="stopped"
    print_status "Stopped ${INSTANCES[$instance_id]}"
    display_service_status
    sleep 2
    
    # Step 2: Update instance
    INSTANCE_STATUS[$instance_id]="updating"
    print_status "Updating ${INSTANCES[$instance_id]}..."
    display_service_status
    sleep 3
    
    # Step 3: Start updated instance
    INSTANCE_VERSIONS[$instance_id]="$NEW_VERSION"
    INSTANCE_STATUS[$instance_id]="running"
    print_status "Started ${INSTANCES[$instance_id]} with version $NEW_VERSION"
    display_service_status
    
    # Step 4: Health check
    if health_check_instance $instance_id; then
        print_success "Health check passed for ${INSTANCES[$instance_id]}"
        return 0
    else
        print_error "Health check failed for ${INSTANCES[$instance_id]}"
        
        # Rollback instance
        INSTANCE_VERSIONS[$instance_id]="$CURRENT_VERSION"
        print_status "Rolled back ${INSTANCES[$instance_id]} to $CURRENT_VERSION"
        display_service_status
        return 1
    fi
}

rolling_update() {
    echo "🔄 Starting Rolling Update"
    echo "=========================="
    echo "Service: $SERVICE_NAME"
    echo "Current Version: $CURRENT_VERSION"
    echo "Target Version: $NEW_VERSION"
    echo "Total Instances: $TOTAL_INSTANCES"
    echo "Batch Size: $BATCH_SIZE"
    echo "Delay Between Batches: ${DELAY_BETWEEN_BATCHES}s"
    echo ""
    
    local instances_to_update=($(seq 1 $TOTAL_INSTANCES))
    local batch_number=1
    local failed_updates=0
    
    while [[ ${#instances_to_update[@]} -gt 0 ]]; do
        print_status "Starting batch $batch_number (updating $BATCH_SIZE instances)"
        
        local current_batch=()
        for i in $(seq 1 $BATCH_SIZE); do
            if [[ ${#instances_to_update[@]} -gt 0 ]]; then
                current_batch+=(${instances_to_update[0]})
                instances_to_update=(${instances_to_update[@]:1})
            fi
        done
        
        # Update instances in current batch
        local batch_failures=0
        for instance_id in "${current_batch[@]}"; do
            if ! update_instance $instance_id; then
                ((batch_failures++))
                ((failed_updates++))
            fi
        done
        
        print_status "Batch $batch_number completed. Failures: $batch_failures"
        
        # Check if we should continue
        if [[ $batch_failures -gt 0 ]]; then
            local failure_rate=$(( (failed_updates * 100) / (batch_number * BATCH_SIZE) ))
            if [[ $failure_rate -gt 20 ]]; then
                print_error "Failure rate too high ($failure_rate%). Stopping rolling update."
                rollback_all_instances
                return 1
            fi
        fi
        
        # Wait before next batch
        if [[ ${#instances_to_update[@]} -gt 0 ]]; then
            print_status "Waiting ${DELAY_BETWEEN_BATCHES}s before next batch..."
            sleep $DELAY_BETWEEN_BATCHES
        fi
        
        ((batch_number++))
    done
    
    # Final verification
    print_status "Performing final service verification..."
    local healthy_instances=0
    
    for i in $(seq 1 $TOTAL_INSTANCES); do
        if [[ "${INSTANCE_STATUS[$i]}" == "running" ]] && [[ "${INSTANCE_VERSIONS[$i]}" == "$NEW_VERSION" ]]; then
            ((healthy_instances++))
        fi
    done
    
    print_status "Rolling update completed!"
    print_status "Healthy instances with new version: $healthy_instances/$TOTAL_INSTANCES"
    
    if [[ $healthy_instances -eq $TOTAL_INSTANCES ]]; then
        print_success "Rolling update successful! All instances updated to $NEW_VERSION"
        return 0
    else
        print_error "Rolling update partially failed. $((TOTAL_INSTANCES - healthy_instances)) instances failed to update."
        return 1
    fi
}

rollback_all_instances() {
    print_status "Initiating rollback of all instances..."
    
    for i in $(seq 1 $TOTAL_INSTANCES); do
        if [[ "${INSTANCE_VERSIONS[$i]}" == "$NEW_VERSION" ]]; then
            INSTANCE_VERSIONS[$i]="$CURRENT_VERSION"
            INSTANCE_STATUS[$i]="running"
            print_status "Rolled back ${INSTANCES[$i]} to $CURRENT_VERSION"
        fi
    done
    
    display_service_status
    print_success "Rollback completed"
}

# Demo execution
echo "Rolling Update Demo"
echo "=================="

initialize_instances
sleep 3

rolling_update

echo ""
echo "Rolling update demonstration completed!"
EOF

chmod +x rolling-update-demo.sh
./rolling-update-demo.sh

print_success "Rolling update demonstration completed"

# Demo 4: Health Check Implementation
print_header "Demo 4: Advanced Health Check System"

echo "Creating comprehensive health check system..."
cat > advanced-healthcheck.js << 'EOF'
// Advanced Health Check System
const http = require('http');
const fs = require('fs').promises;

class ComprehensiveHealthChecker {
    constructor() {
        this.checks = new Map();
        this.thresholds = {
            memory: 90,          // Memory usage percentage
            cpu: 80,             // CPU usage percentage
            responseTime: 5000,  // Response time in ms
            errorRate: 5         // Error rate percentage
        };
        this.metrics = {
            requestCount: 0,
            errorCount: 0,
            totalResponseTime: 0,
            lastResetTime: Date.now()
        };
        this.initializeChecks();
    }
    
    initializeChecks() {
        // Application health checks
        this.addCheck('http_endpoint', this.checkHttpEndpoint.bind(this));
        this.addCheck('database', this.checkDatabase.bind(this));
        this.addCheck('external_services', this.checkExternalServices.bind(this));
        this.addCheck('file_system', this.checkFileSystem.bind(this));
        this.addCheck('memory_usage', this.checkMemoryUsage.bind(this));
        this.addCheck('response_time', this.checkResponseTime.bind(this));
        this.addCheck('error_rate', this.checkErrorRate.bind(this));
        this.addCheck('business_logic', this.checkBusinessLogic.bind(this));
    }
    
    addCheck(name, checkFunction) {
        this.checks.set(name, checkFunction);
    }
    
    async checkHttpEndpoint() {
        return new Promise((resolve) => {
            const start = Date.now();
            const req = http.request({
                hostname: 'localhost',
                port: 3000,
                path: '/api/status',
                method: 'GET',
                timeout: 5000
            }, (res) => {
                const responseTime = Date.now() - start;
                
                if (res.statusCode === 200) {
                    resolve({
                        status: 'healthy',
                        message: 'HTTP endpoint responsive',
                        metrics: { responseTime }
                    });
                } else {
                    resolve({
                        status: 'unhealthy',
                        message: `HTTP endpoint returned ${res.statusCode}`,
                        metrics: { responseTime }
                    });
                }
            });
            
            req.on('error', (error) => {
                resolve({
                    status: 'unhealthy',
                    message: `HTTP check failed: ${error.message}`
                });
            });
            
            req.on('timeout', () => {
                resolve({
                    status: 'unhealthy',
                    message: 'HTTP endpoint timeout'
                });
            });
            
            req.end();
        });
    }
    
    async checkDatabase() {
        // Simulate database connection check
        const connectionTime = Math.random() * 1000; // 0-1000ms
        
        if (connectionTime > 800) {
            return {
                status: 'unhealthy',
                message: 'Database connection timeout',
                metrics: { connectionTime: Math.round(connectionTime) }
            };
        }
        
        return {
            status: 'healthy',
            message: 'Database connection successful',
            metrics: { connectionTime: Math.round(connectionTime) }
        };
    }
    
    async checkExternalServices() {
        const services = [
            { name: 'payment_api', critical: true },
            { name: 'notification_service', critical: false },
            { name: 'analytics_service', critical: false }
        ];
        
        const results = [];
        let criticalFailures = 0;
        
        for (const service of services) {
            // Simulate service check (85% success rate)
            const isHealthy = Math.random() > 0.15;
            const responseTime = Math.random() * 2000;
            
            const result = {
                service: service.name,
                status: isHealthy ? 'healthy' : 'unhealthy',
                critical: service.critical,
                responseTime: Math.round(responseTime)
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
                'All external services accessible',
            details: results
        };
    }
    
    async checkFileSystem() {
        try {
            // Check if we can write to temporary directory
            const testFile = '/tmp/health-check-' + Date.now();
            await fs.writeFile(testFile, 'health check test');
            await fs.unlink(testFile);
            
            // Simulate disk space check
            const diskUsage = Math.random() * 100;
            
            if (diskUsage > 95) {
                return {
                    status: 'unhealthy',
                    message: 'Disk space critically low',
                    metrics: { diskUsage: Math.round(diskUsage) }
                };
            }
            
            if (diskUsage > 85) {
                return {
                    status: 'warning',
                    message: 'Disk space running low',
                    metrics: { diskUsage: Math.round(diskUsage) }
                };
            }
            
            return {
                status: 'healthy',
                message: 'File system accessible',
                metrics: { diskUsage: Math.round(diskUsage) }
            };
        } catch (error) {
            return {
                status: 'unhealthy',
                message: `File system check failed: ${error.message}`
            };
        }
    }
    
    async checkMemoryUsage() {
        const memUsage = process.memoryUsage();
        const usagePercent = (memUsage.heapUsed / memUsage.heapTotal) * 100;
        
        if (usagePercent > this.thresholds.memory) {
            return {
                status: 'unhealthy',
                message: `High memory usage: ${usagePercent.toFixed(1)}%`,
                metrics: {
                    heapUsed: Math.round(memUsage.heapUsed / 1024 / 1024),
                    heapTotal: Math.round(memUsage.heapTotal / 1024 / 1024),
                    usagePercent: Math.round(usagePercent)
                }
            };
        }
        
        if (usagePercent > this.thresholds.memory * 0.8) {
            return {
                status: 'warning',
                message: `Memory usage elevated: ${usagePercent.toFixed(1)}%`,
                metrics: {
                    heapUsed: Math.round(memUsage.heapUsed / 1024 / 1024),
                    heapTotal: Math.round(memUsage.heapTotal / 1024 / 1024),
                    usagePercent: Math.round(usagePercent)
                }
            };
        }
        
        return {
            status: 'healthy',
            message: 'Memory usage normal',
            metrics: {
                heapUsed: Math.round(memUsage.heapUsed / 1024 / 1024),
                heapTotal: Math.round(memUsage.heapTotal / 1024 / 1024),
                usagePercent: Math.round(usagePercent)
            }
        };
    }
    
    async checkResponseTime() {
        const avgResponseTime = this.metrics.requestCount > 0 ? 
            this.metrics.totalResponseTime / this.metrics.requestCount : 0;
        
        if (avgResponseTime > this.thresholds.responseTime) {
            return {
                status: 'unhealthy',
                message: `High average response time: ${avgResponseTime.toFixed(0)}ms`,
                metrics: { avgResponseTime: Math.round(avgResponseTime) }
            };
        }
        
        return {
            status: 'healthy',
            message: 'Response time normal',
            metrics: { avgResponseTime: Math.round(avgResponseTime) }
        };
    }
    
    async checkErrorRate() {
        const errorRate = this.metrics.requestCount > 0 ? 
            (this.metrics.errorCount / this.metrics.requestCount) * 100 : 0;
        
        if (errorRate > this.thresholds.errorRate) {
            return {
                status: 'unhealthy',
                message: `High error rate: ${errorRate.toFixed(1)}%`,
                metrics: {
                    errorCount: this.metrics.errorCount,
                    requestCount: this.metrics.requestCount,
                    errorRate: Math.round(errorRate * 10) / 10
                }
            };
        }
        
        return {
            status: 'healthy',
            message: 'Error rate acceptable',
            metrics: {
                errorCount: this.metrics.errorCount,
                requestCount: this.metrics.requestCount,
                errorRate: Math.round(errorRate * 10) / 10
            }
        };
    }
    
    async checkBusinessLogic() {
        // Simulate business-critical feature checks
        const features = [
            'user_authentication',
            'payment_processing',
            'data_validation',
            'security_middleware'
        ];
        
        for (const feature of features) {
            // 95% success rate for critical features
            if (Math.random() > 0.95) {
                return {
                    status: 'unhealthy',
                    message: `Critical feature unavailable: ${feature}`
                };
            }
        }
        
        return {
            status: 'healthy',
            message: 'All critical features operational'
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
                unhealthy: 0
            }
        };
        
        for (const [name, checkFunction] of this.checks) {
            try {
                const result = await checkFunction();
                results.checks[name] = result;
                
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
                        break;
                }
            } catch (error) {
                results.checks[name] = {
                    status: 'unhealthy',
                    message: `Health check failed: ${error.message}`
                };
                results.summary.unhealthy++;
                results.overall_status = 'unhealthy';
            }
        }
        
        return results;
    }
    
    recordMetrics(responseTime, isError = false) {
        this.metrics.requestCount++;
        this.metrics.totalResponseTime += responseTime;
        
        if (isError) {
            this.metrics.errorCount++;
        }
        
        // Reset metrics every hour
        if (Date.now() - this.metrics.lastResetTime > 3600000) {
            this.resetMetrics();
        }
    }
    
    resetMetrics() {
        this.metrics = {
            requestCount: 0,
            errorCount: 0,
            totalResponseTime: 0,
            lastResetTime: Date.now()
        };
    }
}

// Demo execution
async function demonstrateHealthChecks() {
    console.log('🏥 Advanced Health Check System Demo');
    console.log('===================================');
    
    const healthChecker = new ComprehensiveHealthChecker();
    
    // Simulate some application metrics
    healthChecker.recordMetrics(150, false);
    healthChecker.recordMetrics(320, false);
    healthChecker.recordMetrics(180, true);
    healthChecker.recordMetrics(95, false);
    
    console.log('Running comprehensive health checks...\n');
    
    const results = await healthChecker.runAllChecks();
    
    // Display results
    console.log('Health Check Results:');
    console.log('====================');
    console.log(`Overall Status: ${results.overall_status.toUpperCase()}`);
    console.log(`Timestamp: ${results.timestamp}`);
    console.log(`\nSummary:`);
    console.log(`  Healthy: ${results.summary.healthy}`);
    console.log(`  Warnings: ${results.summary.warnings}`);
    console.log(`  Unhealthy: ${results.summary.unhealthy}`);
    console.log(`  Total: ${results.summary.total}`);
    
    console.log('\nDetailed Results:');
    console.log('-----------------');
    
    for (const [checkName, result] of Object.entries(results.checks)) {
        const statusIcon = result.status === 'healthy' ? '✅' : 
                          result.status === 'warning' ? '⚠️' : '❌';
        
        console.log(`${statusIcon} ${checkName}: ${result.message}`);
        
        if (result.metrics) {
            console.log(`   Metrics: ${JSON.stringify(result.metrics)}`);
        }
        
        if (result.details) {
            console.log(`   Details: ${JSON.stringify(result.details, null, 4)}`);
        }
    }
    
    // Return appropriate exit code
    return results.overall_status === 'unhealthy' ? 1 : 0;
}

// Run the demo
demonstrateHealthChecks()
    .then(exitCode => {
        console.log(`\n🎯 Health check completed with exit code: ${exitCode}`);
        process.exit(exitCode);
    })
    .catch(error => {
        console.error('Health check demo failed:', error);
        process.exit(1);
    });
EOF

echo "Running advanced health check demonstration..."
node advanced-healthcheck.js

print_success "Advanced health check system demonstrated"

# Demo 5: Monitoring and Observability
print_header "Demo 5: Production Monitoring Stack"

echo "Creating monitoring configuration..."
cat > prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "alert_rules.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']

  - job_name: 'application'
    static_configs:
      - targets: ['production-app:3000']
    metrics_path: '/metrics'
    scrape_interval: 10s

  - job_name: 'docker-daemon'
    static_configs:
      - targets: ['localhost:9323']
EOF

cat > alert_rules.yml << 'EOF'
groups:
  - name: production_alerts
    rules:
      - alert: HighMemoryUsage
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes > 0.85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage detected"
          description: "Memory usage is above 85% for more than 5 minutes"

      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage detected"
          description: "CPU usage is above 80% for more than 5 minutes"

      - alert: ContainerDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Container is down"
          description: "Container {{ $labels.instance }} has been down for more than 1 minute"

      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) > 0.1
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected"
          description: "Error rate is above 10% for more than 2 minutes"

      - alert: SlowResponseTime
        expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 2
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Slow response time detected"
          description: "95th percentile response time is above 2 seconds"
EOF

cat > docker-compose.monitoring.yml << 'EOF'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ./alert_rules.yml:/etc/prometheus/alert_rules.yml:ro
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

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3001:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin123
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - grafana_data:/var/lib/grafana
    networks:
      - monitoring

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
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

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: cadvisor
    ports:
      - "8081:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:rw
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
    networks:
      - monitoring

  alertmanager:
    image: prom/alertmanager:latest
    container_name: alertmanager
    ports:
      - "9093:9093"
    volumes:
      - ./alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro
      - alertmanager_data:/alertmanager
    networks:
      - monitoring

volumes:
  prometheus_data:
  grafana_data:
  alertmanager_data:

networks:
  monitoring:
    driver: bridge
EOF

cat > alertmanager.yml << 'EOF'
global:
  smtp_smarthost: 'localhost:587'
  smtp_from: 'alerts@company.com'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'web.hook'

receivers:
  - name: 'web.hook'
    webhook_configs:
      - url: 'http://localhost:5001/webhook'
        send_resolved: true

  - name: 'email-alerts'
    email_configs:
      - to: 'devops@company.com'
        subject: 'Production Alert: {{ .GroupLabels.alertname }}'
        body: |
          {{ range .Alerts }}
          Alert: {{ .Annotations.summary }}
          Description: {{ .Annotations.description }}
          {{ end }}
EOF

print_success "Monitoring configuration created"

echo "To deploy the monitoring stack:"
echo "docker-compose -f docker-compose.monitoring.yml up -d"
echo ""
echo "Access points:"
echo "- Prometheus: http://localhost:9090"
echo "- Grafana: http://localhost:3001 (admin/admin123)"
echo "- Node Exporter: http://localhost:9100"
echo "- cAdvisor: http://localhost:8081"
echo "- AlertManager: http://localhost:9093"

# Demo Summary
print_header "Demo Summary and Next Steps"

echo "Module 6 Production Deployment Demonstrations Completed!"
echo ""
echo "Topics Covered:"
echo "✅ Production-ready application with health checks and metrics"
echo "✅ Blue-green deployment strategy with automated switching"
echo "✅ Rolling update deployment with batch processing"
echo "✅ Comprehensive health check system"
echo "✅ Production monitoring stack with Prometheus and Grafana"

echo ""
echo "Files Created:"
echo "• production-app.js - Production application with metrics"
echo "• Dockerfile.production - Production-ready container build"
echo "• blue-green-demo.sh - Blue-green deployment automation"
echo "• rolling-update-demo.sh - Rolling update simulation"
echo "• advanced-healthcheck.js - Comprehensive health checking"
echo "• prometheus.yml - Metrics collection configuration"
echo "• alert_rules.yml - Monitoring alert definitions"
echo "• docker-compose.monitoring.yml - Complete monitoring stack"

echo ""
echo "🎯 Key Takeaways:"
echo "1. Production deployments require zero-downtime strategies"
echo "2. Health checks are critical for automated deployments"
echo "3. Monitoring and observability enable proactive operations"
echo "4. Automated rollback capabilities ensure service reliability"
echo "5. Resource management and scaling are essential for performance"

echo ""
echo "Ready for Module 7: Container Registries & CI/CD!"
print_success "Module 6 demonstrations completed successfully!"