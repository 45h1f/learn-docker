#!/bin/bash

echo "=== Docker Image Optimization Comparison ==="
echo "This script builds and compares different optimization levels"
echo

cd "$(dirname "$0")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to get image size
get_image_size() {
    docker images --format "table {{.Size}}" "$1" | tail -n +2
}

# Function to build and analyze image
build_and_analyze() {
    local dockerfile=$1
    local tag=$2
    local description=$3
    
    echo -e "${BLUE}Building $description...${NC}"
    echo "Dockerfile: $dockerfile"
    
    # Build image and time it
    start_time=$(date +%s)
    docker build -f "$dockerfile" -t "$tag" . > /dev/null 2>&1
    end_time=$(date +%s)
    build_time=$((end_time - start_time))
    
    if [ $? -eq 0 ]; then
        size=$(get_image_size "$tag")
        echo -e "${GREEN}✓ Build successful${NC}"
        echo "  Build time: ${build_time}s"
        echo "  Image size: $size"
        
        # Check for security issues (non-root user)
        user_check=$(docker run --rm "$tag" whoami 2>/dev/null)
        if [ "$user_check" = "root" ]; then
            echo -e "  ${RED}⚠ Running as root (security risk)${NC}"
        else
            echo -e "  ${GREEN}✓ Running as non-root user: $user_check${NC}"
        fi
        
        # Count layers
        layer_count=$(docker history "$tag" --quiet | wc -l)
        echo "  Layers: $layer_count"
        
        echo
    else
        echo -e "${RED}✗ Build failed${NC}"
        echo
    fi
}

# Clean up any existing images
echo "Cleaning up previous builds..."
docker rmi flask-app:bad flask-app:good flask-app:excellent 2>/dev/null || true
echo

# Build different versions
build_and_analyze "Dockerfile.bad" "flask-app:bad" "BAD example (Ubuntu-based, inefficient)"
build_and_analyze "Dockerfile.good" "flask-app:good" "GOOD example (Python slim, optimized)"
build_and_analyze "Dockerfile.excellent" "flask-app:excellent" "EXCELLENT example (Multi-stage, Alpine)"

# Summary comparison
echo -e "${YELLOW}=== SIZE COMPARISON ===${NC}"
echo "Image Name                Size"
echo "-------------------------"
docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" | grep flask-app

echo
echo -e "${YELLOW}=== LAYER ANALYSIS ===${NC}"
for tag in flask-app:bad flask-app:good flask-app:excellent; do
    if docker images --quiet "$tag" >/dev/null 2>&1; then
        echo "Layers in $tag:"
        docker history "$tag" --format "table {{.CreatedBy}}" | head -5
        echo "Total layers: $(docker history "$tag" --quiet | wc -l)"
        echo
    fi
done

# Test functionality
echo -e "${YELLOW}=== FUNCTIONALITY TEST ===${NC}"
test_image() {
    local tag=$1
    echo "Testing $tag..."
    
    # Run container
    container_id=$(docker run -d -p 0:5000 "$tag")
    sleep 3
    
    # Get the actual port
    port=$(docker port "$container_id" 5000 | cut -d: -f2)
    
    # Test health endpoint
    if curl -s "http://localhost:$port/health" >/dev/null; then
        echo -e "  ${GREEN}✓ Health check passed${NC}"
    else
        echo -e "  ${RED}✗ Health check failed${NC}"
    fi
    
    # Stop container
    docker stop "$container_id" >/dev/null
    docker rm "$container_id" >/dev/null
}

for tag in flask-app:good flask-app:excellent; do
    if docker images --quiet "$tag" >/dev/null 2>&1; then
        test_image "$tag"
    fi
done

echo
echo -e "${GREEN}=== BEST PRACTICES SUMMARY ===${NC}"
echo "1. ✓ Use specific, minimal base images (Alpine, slim)"
echo "2. ✓ Implement multi-stage builds"
echo "3. ✓ Minimize layers by combining RUN commands"
echo "4. ✓ Copy requirements.txt first for better caching"
echo "5. ✓ Run as non-root user for security"
echo "6. ✓ Add health checks"
echo "7. ✓ Use .dockerignore to exclude unnecessary files"
echo "8. ✓ Clean up package caches in the same RUN command"
echo "9. ✓ Use production WSGI server (gunicorn)"
echo "10. ✓ Set proper environment variables"

echo
echo -e "${BLUE}To run the optimized application:${NC}"
echo "docker run -d -p 8080:5000 flask-app:excellent"
echo "Then visit: http://localhost:8080"

echo
echo -e "${YELLOW}Cleanup command:${NC}"
echo "docker rmi flask-app:bad flask-app:good flask-app:excellent"