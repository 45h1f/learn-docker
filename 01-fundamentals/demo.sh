#!/bin/bash

# Docker Fundamentals Practice Script
# This script demonstrates essential Docker commands

echo "=== Docker Fundamentals Demo ==="
echo

# Check Docker installation
echo "1. Checking Docker installation..."
docker --version
docker info | head -10
echo

# Pull and run a simple web server
echo "2. Running nginx web server..."
docker run -d --name demo-nginx -p 8080:80 nginx:alpine
echo "Nginx started on http://localhost:8080"
echo

# Show running containers
echo "3. Listing running containers..."
docker ps
echo

# Create custom HTML content
echo "4. Creating custom HTML content..."
mkdir -p ./html
cat > ./html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Docker Demo</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f0f0f0; }
        .container { background: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #2196F3; }
        .info { background: #e3f2fd; padding: 15px; margin: 10px 0; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🐳 Welcome to Docker!</h1>
        <div class="info">
            <strong>Container ID:</strong> <span id="hostname"></span><br>
            <strong>Server:</strong> Nginx running in Docker<br>
            <strong>Status:</strong> Successfully containerized!
        </div>
        <p>This page is served from a Docker container with custom HTML content.</p>
        <h3>Docker Benefits:</h3>
        <ul>
            <li>Consistent environments across development, staging, and production</li>
            <li>Isolated applications with their dependencies</li>
            <li>Efficient resource utilization</li>
            <li>Easy scaling and deployment</li>
            <li>Platform independence</li>
        </ul>
    </div>
    <script>
        document.getElementById('hostname').textContent = window.location.hostname;
    </script>
</body>
</html>
EOF

# Run nginx with custom content
echo "5. Running nginx with custom HTML..."
docker stop demo-nginx && docker rm demo-nginx
docker run -d --name demo-nginx -p 8080:80 -v "$(pwd)/html:/usr/share/nginx/html" nginx:alpine
echo "Custom page available at http://localhost:8080"
echo

# Demonstrate container execution
echo "6. Executing commands in container..."
echo "Container hostname:"
docker exec demo-nginx hostname
echo "Container processes:"
docker exec demo-nginx ps aux
echo "Nginx configuration check:"
docker exec demo-nginx nginx -t
echo

# Show container logs
echo "7. Container logs (last 10 lines):"
docker logs --tail 10 demo-nginx
echo

# Demonstrate interactive container
echo "8. Running interactive Ubuntu container..."
echo "Starting Ubuntu container for 30 seconds..."
docker run -d --name demo-ubuntu ubuntu:20.04 sleep 30

echo "Installing curl in Ubuntu container..."
docker exec demo-ubuntu bash -c "apt update >/dev/null 2>&1 && apt install -y curl >/dev/null 2>&1"

echo "Testing network connectivity from Ubuntu container:"
docker exec demo-ubuntu curl -s http://demo-nginx/
echo

# Resource monitoring
echo "9. Container resource usage:"
docker stats --no-stream demo-nginx demo-ubuntu
echo

# Environment variables demo
echo "10. Environment variables demo..."
docker run --rm -e ENV=development -e DEBUG=true alpine:latest env | grep -E "(ENV|DEBUG)"
echo

# Volume demonstration
echo "11. Volume persistence demo..."
docker run -d --name demo-data -v demo_volume:/data alpine:latest sleep 60
docker exec demo-data sh -c "echo 'Persistent data!' > /data/message.txt"
echo "Data written to volume. Checking content:"
docker exec demo-data cat /data/message.txt

# Restart container and check persistence
docker restart demo-data
sleep 2
echo "After restart, data still exists:"
docker exec demo-data cat /data/message.txt
echo

# Cleanup function
cleanup() {
    echo "12. Cleaning up demo containers and volumes..."
    docker stop demo-nginx demo-ubuntu demo-data 2>/dev/null || true
    docker rm demo-nginx demo-ubuntu demo-data 2>/dev/null || true
    docker volume rm demo_volume 2>/dev/null || true
    rm -rf ./html
    echo "Cleanup completed!"
}

# Set trap for cleanup on script exit
trap cleanup EXIT

echo "=== Demo completed! ==="
echo "Visit http://localhost:8080 to see the custom webpage"
echo "Press Ctrl+C to cleanup and exit"
echo "Or run: docker stop demo-nginx && docker rm demo-nginx"

# Keep script running to allow testing
read -p "Press Enter to cleanup and exit..."