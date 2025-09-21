# Module 3: Container Orchestration & Docker Compose

## 🎯 Learning Objectives
- Master Docker Compose for multi-container applications
- Understand service definitions and dependencies
- Learn networking and volume management in Compose
- Implement environment-specific configurations
- Apply container orchestration patterns

## 📖 Theory: Docker Compose Deep Dive

### What is Docker Compose?
Docker Compose is a tool for defining and running multi-container Docker applications. With Compose, you use a YAML file to configure your application's services, networks, and volumes.

### Key Benefits:
- **Declarative Configuration**: Define your entire stack in code
- **Environment Management**: Easy switching between dev/staging/prod
- **Service Dependencies**: Define startup order and dependencies
- **Network Isolation**: Automatic network creation and management
- **Volume Management**: Persistent data across container restarts
- **Scaling**: Easy horizontal scaling of services

### Compose File Structure:
```yaml
version: '3.8'

services:
  web:
    # Service configuration
  
  database:
    # Service configuration

networks:
  # Custom networks

volumes:
  # Named volumes
```

## 🛠️ Docker Compose Fundamentals

### Basic Compose File Anatomy

```yaml
version: '3.8'

services:
  # Web application service
  web:
    build: .                    # Build from current directory
    ports:
      - "8080:80"              # Host:Container port mapping
    environment:
      - ENV=production         # Environment variables
    depends_on:
      - database               # Service dependencies
    volumes:
      - ./app:/var/www/html    # Volume mounts
    networks:
      - app-network            # Custom networks

  # Database service
  database:
    image: postgres:13         # Use pre-built image
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: admin
      POSTGRES_PASSWORD: secret
    volumes:
      - db_data:/var/lib/postgresql/data  # Named volume
    networks:
      - app-network

# Define custom networks
networks:
  app-network:
    driver: bridge

# Define named volumes
volumes:
  db_data:
    driver: local
```

### Essential Compose Commands

```bash
# Start services
docker-compose up                    # Foreground
docker-compose up -d                 # Background (detached)
docker-compose up --build            # Rebuild images

# Stop services
docker-compose down                  # Stop and remove containers
docker-compose down -v               # Also remove volumes
docker-compose stop                  # Stop without removing

# View status
docker-compose ps                    # List containers
docker-compose logs                  # View logs
docker-compose logs -f web           # Follow logs for specific service

# Scale services
docker-compose up --scale web=3      # Run 3 instances of web service

# Execute commands
docker-compose exec web bash         # Execute in running container
docker-compose run web python manage.py migrate  # Run one-off command
```

## 🏗️ Hands-on Lab 1: Basic Multi-Container Application

Let's create a complete web application stack with frontend, backend, and database:

### Step 1: Explore the Complete Stack

The webapp directory contains a full-stack application with:
- **Flask Web Application** (`app.py`) - Python backend with database and cache integration
- **PostgreSQL Database** - Persistent data storage with initialization scripts
- **Redis Cache** - In-memory caching and session storage
- **Nginx Reverse Proxy** - Load balancing and SSL termination
- **Admin Tools** - pgAdmin for database management, Redis Commander for cache management

### Step 2: Start the Complete Stack

```bash
cd /home/ashif/Projects/personal/Docker/lean_docker/03-compose-orchestration

# Start all services
docker-compose up -d

# Watch the logs
docker-compose logs -f

# Check service status
docker-compose ps
```

### Step 3: Access the Applications

Once all services are running, you can access:

| Service | URL | Description |
|---------|-----|-------------|
| Main App | http://localhost:8080 | Full-stack web application |
| Nginx Proxy | http://localhost | Load-balanced application |
| pgAdmin | http://localhost:8081 | Database administration |
| Redis Admin | http://localhost:8082 | Cache administration |

**Login Credentials:**
- pgAdmin: admin@example.com / admin
- Database: admin / secret

## 🔧 Docker Compose Commands Deep Dive

### Service Management
```bash
# Start specific services
docker-compose up web database

# Start in background
docker-compose up -d

# Rebuild and start
docker-compose up --build

# Force recreate containers
docker-compose up --force-recreate

# Start with custom compose file
docker-compose -f docker-compose.prod.yml up
```

### Scaling Services
```bash
# Scale web service to 3 replicas
docker-compose up --scale web=3

# Scale multiple services
docker-compose up --scale web=3 --scale cache=2
```

### Service Logs
```bash
# View all logs
docker-compose logs

# Follow logs for specific service
docker-compose logs -f web

# Show last 50 lines
docker-compose logs --tail=50 web

# View logs since timestamp
docker-compose logs --since 2023-01-01T00:00:00Z
```

### Container Management
```bash
# Stop services
docker-compose stop

# Stop specific service
docker-compose stop web

# Restart services
docker-compose restart

# Remove stopped containers
docker-compose rm

# Stop and remove everything
docker-compose down

# Remove volumes too
docker-compose down -v

# Remove images too
docker-compose down --rmi all
```

### Executing Commands
```bash
# Execute command in running container
docker-compose exec web bash

# Run one-off command
docker-compose run web python manage.py migrate

# Run command as different user
docker-compose exec -u root web bash

# Run command in specific working directory
docker-compose exec -w /app web ls -la
```

## 📊 Advanced Compose Features

### Environment Variables and Secrets

**Method 1: Environment File**
```bash
# Create .env file
cat > .env << 'EOF'
# Database Configuration
DB_HOST=database
DB_NAME=webapp
DB_USER=admin
DB_PASSWORD=my_secret_password

# Application Configuration
FLASK_ENV=production
APP_VERSION=2.0.0
DEBUG=false

# External Services
REDIS_URL=redis://cache:6379/0
MAIL_SERVER=smtp.example.com
MAIL_PORT=587
EOF
```

**Method 2: External Environment File**
```yaml
# docker-compose.yml
services:
  web:
    env_file:
      - ./config/web.env
      - ./config/database.env
```

**Method 3: Environment Substitution**
```yaml
services:
  web:
    image: myapp:${APP_VERSION:-latest}
    environment:
      - DATABASE_URL=postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}/${DB_NAME}
```

### Health Checks and Dependencies

```yaml
services:
  database:
    image: postgres:13
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER} -d ${DB_NAME}"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  web:
    depends_on:
      database:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 30s
      timeout: 3s
      retries: 3
```

### Custom Networks

```yaml
networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true  # No external access

services:
  web:
    networks:
      - frontend
      - backend
  
  database:
    networks:
      - backend  # Only accessible from backend network
```

### Volume Configurations

```yaml
volumes:
  # Named volume with driver options
  db_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /opt/data/postgresql

  # External volume
  external_data:
    external: true

  # Temporary volume
  temp_data:
    driver_opts:
      type: tmpfs
      device: tmpfs

services:
  database:
    volumes:
      - db_data:/var/lib/postgresql/data
      - ./backups:/backups:ro  # Read-only mount
      - temp_data:/tmp
```

## 🏗️ Production Compose Configurations

### Production docker-compose.yml

```yaml
version: '3.8'

services:
  web:
    image: myregistry.com/webapp:${APP_VERSION}
    deploy:
      replicas: 3
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 256M
    environment:
      - FLASK_ENV=production
      - WORKERS=4
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  database:
    image: postgres:13-alpine
    environment:
      - POSTGRES_DB=${DB_NAME}
      - POSTGRES_USER=${DB_USER}
      - POSTGRES_PASSWORD_FILE=/run/secrets/db_password
    secrets:
      - db_password
    volumes:
      - db_data:/var/lib/postgresql/data
    deploy:
      placement:
        constraints: [node.role == manager]

secrets:
  db_password:
    external: true

volumes:
  db_data:
    driver: local
```

### Development Override

```yaml
# docker-compose.override.yml
version: '3.8'

services:
  web:
    build: .
    volumes:
      - .:/app
    environment:
      - FLASK_ENV=development
      - DEBUG=true
    ports:
      - "5000:5000"
    
  database:
    ports:
      - "5432:5432"  # Expose for local development tools
```

### Testing Configuration

```yaml
# docker-compose.test.yml
version: '3.8'

services:
  web:
    build: .
    environment:
      - FLASK_ENV=testing
      - DB_NAME=test_db
    command: python -m pytest tests/
    depends_on:
      - test_database

  test_database:
    image: postgres:13-alpine
    environment:
      - POSTGRES_DB=test_db
      - POSTGRES_USER=test_user
      - POSTGRES_PASSWORD=test_pass
    tmpfs:
      - /var/lib/postgresql/data  # Use tmpfs for faster tests
```

## 🔐 Security Best Practices

### 1. Use Secrets Management
```yaml
services:
  web:
    secrets:
      - db_password
      - api_key
    environment:
      - DB_PASSWORD_FILE=/run/secrets/db_password

secrets:
  db_password:
    file: ./secrets/db_password.txt
  api_key:
    external: true
```

### 2. Network Isolation
```yaml
networks:
  frontend:
    # Public-facing services
  backend:
    internal: true  # No internet access
  database:
    internal: true  # Database-only network

services:
  nginx:
    networks: [frontend]
  
  web:
    networks: [frontend, backend]
  
  database:
    networks: [database, backend]
```

### 3. Resource Limits
```yaml
services:
  web:
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
          pids: 100
    ulimits:
      nofile:
        soft: 1024
        hard: 2048
```

### 4. Read-Only Filesystems
```yaml
services:
  web:
    read_only: true
    tmpfs:
      - /tmp
      - /var/cache
    volumes:
      - app_data:/app/data  # Only writable volume
```

## 🧪 Hands-on Lab 2: Environment-Specific Configurations

Let's create different configurations for different environments:

### Development Environment
```bash
# docker-compose.dev.yml
version: '3.8'

services:
  web:
    build: .
    volumes:
      - .:/app
    environment:
      - FLASK_ENV=development
      - DEBUG=true
    ports:
      - "8080:5000"

  database:
    ports:
      - "5432:5432"
```

### Staging Environment
```bash
# docker-compose.staging.yml  
version: '3.8'

services:
  web:
    image: myregistry.com/webapp:staging
    environment:
      - FLASK_ENV=staging
    deploy:
      replicas: 2

  database:
    volumes:
      - staging_db_data:/var/lib/postgresql/data

volumes:
  staging_db_data:
```

### Production Environment
```bash
# docker-compose.prod.yml
version: '3.8'

services:
  web:
    image: myregistry.com/webapp:${APP_VERSION}
    environment:
      - FLASK_ENV=production
    deploy:
      replicas: 3
      resources:
        limits:
          memory: 512M
    logging:
      driver: "fluentd"
      options:
        fluentd-address: logs.company.com:24224

  database:
    environment:
      - POSTGRES_PASSWORD_FILE=/run/secrets/db_password
    secrets:
      - db_password

secrets:
  db_password:
    external: true
```

### Usage Commands
```bash
# Development
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up

# Staging  
docker-compose -f docker-compose.yml -f docker-compose.staging.yml up

# Production
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up
```