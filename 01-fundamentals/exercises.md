# Docker Fundamentals - Practical Exercises

## 🎯 Exercise 1: Container Basics

### Task: Web Server Setup
Create a simple web server environment with custom content.

**Steps:**
1. Create a directory for your HTML content
2. Create an `index.html` file with your personal information
3. Run an nginx container serving your content
4. Test access from browser and curl

**Commands to try:**
```bash
mkdir -p ./my-website
echo "<h1>My Name: [Your Name]</h1><p>Learning Docker!</p>" > ./my-website/index.html
docker run -d --name my-web -p 8080:80 -v $(pwd)/my-website:/usr/share/nginx/html nginx:alpine
curl http://localhost:8080
```

**Expected outcome:** Your custom webpage loads successfully

---

## 🎯 Exercise 2: Database Container

### Task: Development Database Setup
Set up a MySQL database for development with initialization.

**Steps:**
1. Run a MySQL container with environment variables
2. Create a database and table
3. Insert sample data
4. Query the data

**Commands to try:**
```bash
# Start MySQL container
docker run -d \
  --name dev-mysql \
  -e MYSQL_ROOT_PASSWORD=rootpass \
  -e MYSQL_DATABASE=testdb \
  -e MYSQL_USER=devuser \
  -e MYSQL_PASSWORD=devpass \
  -p 3306:3306 \
  mysql:8.0

# Wait for MySQL to start (check logs)
docker logs dev-mysql

# Connect and create data
docker exec -it dev-mysql mysql -u devuser -pdevpass testdb

# Inside MySQL:
CREATE TABLE products (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(100), price DECIMAL(10,2));
INSERT INTO products (name, price) VALUES ('Laptop', 999.99), ('Mouse', 29.99);
SELECT * FROM products;
EXIT;
```

**Expected outcome:** Database runs with your sample data

---

## 🎯 Exercise 3: Multi-Container Communication

### Task: Web App + Database
Create a web application that connects to a database.

**Steps:**
1. Create a network for containers to communicate
2. Run database container on the network
3. Run a web application container that connects to the database
4. Test the connection

**Commands to try:**
```bash
# Create network
docker network create app-network

# Run database
docker run -d \
  --name app-db \
  --network app-network \
  -e POSTGRES_DB=appdb \
  -e POSTGRES_USER=appuser \
  -e POSTGRES_PASSWORD=apppass \
  postgres:13

# Run adminer (database admin tool)
docker run -d \
  --name app-admin \
  --network app-network \
  -p 8080:8080 \
  adminer:latest

# Test connection via adminer web interface
echo "Visit http://localhost:8080"
echo "Server: app-db"
echo "Username: appuser"
echo "Password: apppass"
echo "Database: appdb"
```

**Expected outcome:** You can connect to the database via the web interface

---

## 🎯 Exercise 4: Environment Management

### Task: Configuration with Environment Variables
Run containers with different configurations using environment variables.

**Commands to try:**
```bash
# Development environment
docker run -d \
  --name app-dev \
  -e NODE_ENV=development \
  -e DEBUG=true \
  -e PORT=3000 \
  -p 3000:3000 \
  node:16-alpine \
  sh -c 'echo "Environment: $NODE_ENV, Debug: $DEBUG" && sleep 300'

# Production environment
docker run -d \
  --name app-prod \
  -e NODE_ENV=production \
  -e DEBUG=false \
  -e PORT=3000 \
  -p 3001:3000 \
  node:16-alpine \
  sh -c 'echo "Environment: $NODE_ENV, Debug: $DEBUG" && sleep 300'

# Check environment variables
docker exec app-dev env | grep -E "(NODE_ENV|DEBUG|PORT)"
docker exec app-prod env | grep -E "(NODE_ENV|DEBUG|PORT)"
```

**Expected outcome:** Different configurations in each container

---

## 🎯 Exercise 5: Volume Persistence

### Task: Data Persistence
Demonstrate data persistence across container restarts.

**Commands to try:**
```bash
# Create named volume
docker volume create my-data

# Run container with volume
docker run -d \
  --name data-container \
  -v my-data:/app/data \
  alpine:latest \
  sh -c 'echo "Initial data" > /app/data/file.txt && sleep 300'

# Check data
docker exec data-container cat /app/data/file.txt

# Stop and remove container
docker stop data-container
docker rm data-container

# Run new container with same volume
docker run -d \
  --name data-container-2 \
  -v my-data:/app/data \
  alpine:latest \
  sleep 300

# Check if data persists
docker exec data-container-2 cat /app/data/file.txt

# Add more data
docker exec data-container-2 sh -c 'echo "More data" >> /app/data/file.txt'
docker exec data-container-2 cat /app/data/file.txt
```

**Expected outcome:** Data persists across different containers

---

## 🎯 Exercise 6: Container Resource Management

### Task: Resource Limits and Monitoring
Set resource limits and monitor container performance.

**Commands to try:**
```bash
# Run container with resource limits
docker run -d \
  --name limited-app \
  --memory=128m \
  --cpus=0.5 \
  alpine:latest \
  sh -c 'while true; do echo "Working..."; sleep 1; done'

# Monitor resource usage
docker stats limited-app --no-stream

# Try to exceed memory limit
docker exec limited-app sh -c '
  echo "Allocating memory..."
  dd if=/dev/zero of=/tmp/bigfile bs=1M count=200 2>/dev/null || echo "Memory limit reached!"
'

# Check container status
docker ps -a --filter name=limited-app
```

**Expected outcome:** Container respects resource limits

---

## 🎯 Exercise 7: Container Logs and Debugging

### Task: Log Management and Troubleshooting
Practice viewing and managing container logs.

**Commands to try:**
```bash
# Run container that generates logs
docker run -d \
  --name log-generator \
  alpine:latest \
  sh -c 'for i in $(seq 1 100); do echo "Log entry $i: $(date)"; sleep 2; done'

# View logs in different ways
docker logs log-generator                    # All logs
docker logs --tail 10 log-generator         # Last 10 lines
docker logs --since 30s log-generator       # Last 30 seconds
docker logs -f log-generator                # Follow logs (Ctrl+C to stop)

# Run a problematic container
docker run --name problem-container alpine:latest invalid-command || true

# Check why it failed
docker logs problem-container
docker ps -a --filter name=problem-container
```

**Expected outcome:** You can effectively view and analyze container logs

---

## 🎯 Exercise 8: Interactive Debugging

### Task: Debug Running Containers
Practice debugging techniques for containers.

**Commands to try:**
```bash
# Run a web server
docker run -d --name debug-web -p 8080:80 nginx:alpine

# Inspect the container
docker inspect debug-web | head -20

# Enter the container for debugging
docker exec -it debug-web sh

# Inside container:
ps aux                          # See running processes
netstat -tlnp                   # Check listening ports
ls -la /usr/share/nginx/html/   # Check web files
cat /var/log/nginx/access.log   # Check logs
exit

# Check container processes from host
docker top debug-web

# Get container IP address
docker inspect debug-web | grep IPAddress
```

**Expected outcome:** You can effectively debug container issues

---

## 🧪 Challenge Exercise: Complete Web Stack

### Task: Build a Complete Development Environment
Combine everything you've learned to create a full web development stack.

**Requirements:**
1. Web server (nginx) serving static content
2. Application server (node.js or python)
3. Database (postgresql or mysql)
4. Cache (redis)
5. All containers should communicate
6. Data should persist
7. Logs should be accessible

**Starter commands:**
```bash
# Create network
docker network create webstack

# Create volumes
docker volume create db_data
docker volume create app_logs

# Your task: Complete the setup!
```

**Expected outcome:** A fully functional web development environment

---

## 📝 Exercise Checklist

- [ ] Exercise 1: Basic web server setup
- [ ] Exercise 2: Database container configuration
- [ ] Exercise 3: Multi-container networking
- [ ] Exercise 4: Environment variable management
- [ ] Exercise 5: Volume persistence testing
- [ ] Exercise 6: Resource limit configuration
- [ ] Exercise 7: Log management and debugging
- [ ] Exercise 8: Interactive container debugging
- [ ] Challenge: Complete web stack

---

## 🎓 Completion Criteria

You've mastered Docker fundamentals when you can:
- ✅ Run containers with various configurations
- ✅ Manage container lifecycle (start, stop, restart, remove)
- ✅ Use volumes for data persistence
- ✅ Configure container networking
- ✅ Debug container issues effectively
- ✅ Monitor container resource usage
- ✅ Handle environment variables and configuration

**Ready for the next module?** Continue to Module 2: Docker Images & Dockerfile Best Practices!