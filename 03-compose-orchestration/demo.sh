#!/bin/bash

# Docker Compose Demo Script
# This script demonstrates Docker Compose functionality with a full-stack application

cd "$(dirname "$0")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Function to wait for user input
wait_for_user() {
    echo -e "${YELLOW}Press Enter to continue or Ctrl+C to exit...${NC}"
    read -r
}

# Function to check if service is healthy
check_service_health() {
    local service=$1
    local max_attempts=30
    local attempt=1
    
    echo -e "${YELLOW}Waiting for $service to be healthy...${NC}"
    
    while [ $attempt -le $max_attempts ]; do
        if docker-compose ps | grep "$service" | grep -q "healthy\|Up"; then
            print_success "$service is healthy!"
            return 0
        fi
        
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    print_error "$service failed to become healthy"
    return 1
}

# Main demo script
print_header "Docker Compose Full-Stack Demo"

print_info "This demo will show you:"
echo "  • Multi-container application orchestration"
echo "  • Service dependencies and networking"
echo "  • Volume management and data persistence"  
echo "  • Environment-specific configurations"
echo "  • Scaling and load balancing"
echo "  • Health checks and monitoring"
echo

wait_for_user

print_header "Step 1: Project Structure Overview"

print_info "Our application stack includes:"
echo "  🌐 Flask Web Application (Python)"
echo "  🗄️  PostgreSQL Database"
echo "  ⚡ Redis Cache"
echo "  🔄 Nginx Reverse Proxy"
echo "  🛠️  Admin Tools (pgAdmin, Redis Commander)"
echo

print_info "Project structure:"
find . -name "docker-compose*" -o -name "Dockerfile" -o -name "*.py" -o -name "*.conf" -o -name "*.sql" | sort

echo
wait_for_user

print_header "Step 2: Building and Starting Services"

print_info "Starting the complete stack..."
docker-compose down -v 2>/dev/null || true  # Clean start

print_info "Building custom images..."
docker-compose build

print_info "Starting services in background..."
docker-compose up -d

echo
print_info "Service status:"
docker-compose ps

echo
print_header "Step 3: Waiting for Services to Initialize"

# Check each service
check_service_health "database"
check_service_health "cache" 
check_service_health "web"

echo
print_info "All core services are running!"

wait_for_user

print_header "Step 4: Service Discovery and Networking"

print_info "Docker Compose automatically creates a network for service communication"
echo "Network details:"
docker network ls | grep "compose"

echo
print_info "Services can communicate using their service names:"
echo "  • web → database (postgresql://admin:secret@database:5432/webapp)"
echo "  • web → cache (redis://cache:6379)"
echo "  • nginx → web (http://web:5000)"

echo
print_info "Testing inter-service communication:"
docker-compose exec web python -c "
import psycopg2
import redis

# Test database connection
try:
    conn = psycopg2.connect(host='database', database='webapp', user='admin', password='secret')
    print('✓ Database connection successful')
    conn.close()
except Exception as e:
    print(f'✗ Database connection failed: {e}')

# Test Redis connection  
try:
    r = redis.Redis(host='cache', port=6379)
    r.ping()
    print('✓ Redis connection successful')
except Exception as e:
    print(f'✗ Redis connection failed: {e}')
"

wait_for_user

print_header "Step 5: Testing the Application"

print_info "Application endpoints:"
echo "  • Main App:    http://localhost:8080"
echo "  • Nginx Proxy: http://localhost"
echo "  • pgAdmin:     http://localhost:8081 (admin@example.com/admin)"
echo "  • Redis Admin: http://localhost:8082"

echo
print_info "Testing application health:"
if curl -s http://localhost:8080/health >/dev/null; then
    print_success "Application is responding!"
    echo "Health check response:"
    curl -s http://localhost:8080/health | python3 -m json.tool 2>/dev/null || curl -s http://localhost:8080/health
else
    print_warning "Application might still be starting up..."
fi

echo
print_info "Testing database API:"
if curl -s http://localhost:8080/api/test-db >/dev/null; then
    echo "Database test response:"
    curl -s http://localhost:8080/api/test-db | python3 -m json.tool 2>/dev/null || curl -s http://localhost:8080/api/test-db
fi

echo
wait_for_user

print_header "Step 6: Volume Management and Data Persistence"

print_info "Docker Compose volumes:"
docker volume ls | grep "compose"

echo
print_info "Volume details:"
docker-compose config --volumes

echo
print_info "Testing data persistence..."
echo "Adding test data to database:"
docker-compose exec database psql -U admin -d webapp -c "
CREATE TABLE IF NOT EXISTS test_data (id SERIAL PRIMARY KEY, message TEXT, created_at TIMESTAMP DEFAULT NOW());
INSERT INTO test_data (message) VALUES ('Docker Compose Demo Data');
SELECT * FROM test_data;
"

echo
print_info "Adding test data to Redis:"
docker-compose exec cache redis-cli SET demo_key "Docker Compose Redis Test" EX 3600
docker-compose exec cache redis-cli GET demo_key

wait_for_user

print_header "Step 7: Scaling Services"

print_info "Current service status:"
docker-compose ps

echo
print_info "Scaling web service to 3 replicas..."
docker-compose up -d --scale web=3

echo
print_info "Updated service status:"
docker-compose ps

echo
print_info "Load balancing test:"
echo "Making multiple requests to see different container responses:"
for i in {1..5}; do
    echo -n "Request $i: "
    curl -s http://localhost/api/stats | grep -o '"hostname":"[^"]*"' || echo "No response"
    sleep 1
done

wait_for_user

print_header "Step 8: Logs and Monitoring"

print_info "Viewing service logs:"
echo "Last 10 lines from each service:"

echo
echo "=== Web Service Logs ==="
docker-compose logs --tail=5 web

echo
echo "=== Database Logs ==="  
docker-compose logs --tail=5 database

echo
echo "=== Cache Logs ==="
docker-compose logs --tail=5 cache

echo
print_info "To follow logs in real-time, run:"
echo "  docker-compose logs -f"
echo "  docker-compose logs -f web  # Specific service"

wait_for_user

print_header "Step 9: Environment Variables and Configuration"

print_info "Checking environment variables in web service:"
docker-compose exec web env | grep -E "(FLASK|DB|REDIS)" | sort

echo
print_info "Service configuration from docker-compose.yml:"
docker-compose config | grep -A 5 -B 5 environment

wait_for_user

print_header "Step 10: Health Checks and Service Dependencies"

print_info "Health check status:"
docker-compose ps | grep -E "(healthy|unhealthy)"

echo
print_info "Service dependency graph:"
echo "  nginx → web → database"
echo "         └→ cache"

echo
print_info "Testing what happens when a dependency fails:"
print_warning "Stopping database service temporarily..."
docker-compose stop database

echo "Waiting 5 seconds..."
sleep 5

echo "Testing application (should show database error):"
curl -s http://localhost:8080/api/test-db | python3 -m json.tool 2>/dev/null || echo "Database unavailable"

print_info "Restarting database..."
docker-compose start database

check_service_health "database"

wait_for_user

print_header "Step 11: Resource Usage and Performance"

print_info "Container resource usage:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" $(docker-compose ps -q)

echo
print_info "Docker Compose service resource limits:"
docker-compose config | grep -A 10 -B 2 "cpus\|memory"

wait_for_user

print_header "Step 12: Cleanup and Teardown"

print_info "Cleanup options:"
echo "  1. Stop services:           docker-compose stop"
echo "  2. Stop and remove:         docker-compose down"  
echo "  3. Remove with volumes:     docker-compose down -v"
echo "  4. Remove with images:      docker-compose down --rmi all"

echo
print_warning "Choose cleanup level:"
echo "  [1] Stop only"
echo "  [2] Remove containers (keep volumes/images)"  
echo "  [3] Remove everything including volumes"
echo "  [4] Keep running for manual exploration"

read -p "Enter choice (1-4): " choice

case $choice in
    1)
        print_info "Stopping services..."
        docker-compose stop
        ;;
    2)
        print_info "Removing containers..."
        docker-compose down
        ;;
    3)
        print_info "Removing everything..."
        docker-compose down -v --rmi local
        ;;
    4)
        print_info "Keeping services running..."
        echo
        print_success "Demo completed! Services are still running."
        echo "Access your application at: http://localhost:8080"
        echo "Stop with: docker-compose down"
        exit 0
        ;;
    *)
        print_warning "Invalid choice. Stopping services..."
        docker-compose stop
        ;;
esac

echo
print_header "Demo Summary"

print_success "Docker Compose Demo Completed!"
echo
print_info "What you learned:"
echo "  ✓ Multi-container application orchestration"
echo "  ✓ Service networking and communication"
echo "  ✓ Volume management and data persistence"
echo "  ✓ Service scaling and load balancing"
echo "  ✓ Health checks and dependencies"
echo "  ✓ Logging and monitoring"
echo "  ✓ Environment configuration"
echo "  ✓ Cleanup and maintenance"

echo
print_info "Next steps:"
echo "  • Explore environment-specific configurations"
echo "  • Learn Docker Swarm for production orchestration"
echo "  • Study Kubernetes for advanced container orchestration"
echo "  • Implement CI/CD pipelines with Docker Compose"

echo
print_success "Ready for Module 4: Docker Networking & Storage!"