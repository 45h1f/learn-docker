# Docker Command Quick Reference

## 🚀 Image Commands
```bash
# Pull image from registry
docker pull <image>:<tag>

# List local images
docker images
docker image ls

# Build image from Dockerfile
docker build -t <name>:<tag> .
docker build -t <name>:<tag> -f <dockerfile> <context>

# Remove image
docker rmi <image>
docker image rm <image>

# Search Docker Hub
docker search <term>

# Show image history
docker history <image>

# Tag image
docker tag <source> <target>
```

## 🔄 Container Commands
```bash
# Run container
docker run <image>
docker run -d <image>                    # Detached mode
docker run -it <image>                   # Interactive mode
docker run --name <name> <image>         # Named container
docker run -p <host>:<container> <image> # Port mapping
docker run -v <host>:<container> <image> # Volume mounting
docker run -e <key>=<value> <image>      # Environment variable

# List containers
docker ps                               # Running containers
docker ps -a                            # All containers
docker ps -q                            # Container IDs only

# Container lifecycle
docker start <container>                # Start stopped container
docker stop <container>                 # Stop running container
docker restart <container>              # Restart container
docker pause <container>                # Pause container
docker unpause <container>              # Unpause container
docker kill <container>                 # Force kill container
docker rm <container>                   # Remove container
docker rm -f <container>                # Force remove running container

# Execute commands
docker exec <container> <command>       # Execute command
docker exec -it <container> bash        # Interactive shell
docker exec -u <user> <container> <cmd> # Run as specific user
```

## 📊 Information & Monitoring
```bash
# Container information
docker logs <container>                 # View logs
docker logs -f <container>              # Follow logs
docker logs --tail 10 <container>       # Last 10 lines
docker logs --since 1h <container>      # Last hour

docker inspect <container>              # Detailed info
docker stats <container>                # Resource usage
docker top <container>                  # Process list
docker port <container>                 # Port mappings

# System information
docker info                             # System info
docker version                          # Version info
docker system df                        # Disk usage
docker system events                    # Real-time events
```

## 🌐 Network Commands
```bash
# List networks
docker network ls

# Create network
docker network create <network>
docker network create --driver bridge <network>

# Connect container to network
docker network connect <network> <container>

# Disconnect container from network
docker network disconnect <network> <container>

# Inspect network
docker network inspect <network>

# Remove network
docker network rm <network>
```

## 💾 Volume Commands
```bash
# List volumes
docker volume ls

# Create volume
docker volume create <volume>

# Inspect volume
docker volume inspect <volume>

# Remove volume
docker volume rm <volume>

# Mount volume
docker run -v <volume>:<path> <image>

# Bind mount
docker run -v <host-path>:<container-path> <image>

# Mount with options
docker run -v <volume>:<path>:ro <image>  # Read-only
```

## 🧹 Cleanup Commands
```bash
# Remove stopped containers
docker container prune

# Remove unused images
docker image prune
docker image prune -a                   # Remove all unused images

# Remove unused volumes
docker volume prune

# Remove unused networks
docker network prune

# Remove everything unused
docker system prune
docker system prune -a                  # More aggressive cleanup

# Remove all containers (force)
docker rm -f $(docker ps -aq)

# Remove all images
docker rmi $(docker images -q)
```

## 🔧 Common Patterns
```bash
# Run temporary container (auto-remove)
docker run --rm <image>

# Run with multiple ports
docker run -p 80:80 -p 443:443 <image>

# Run with multiple environment variables
docker run -e VAR1=value1 -e VAR2=value2 <image>

# Run with environment file
docker run --env-file .env <image>

# Run with resource limits
docker run --memory=512m --cpus=1.5 <image>

# Run with restart policy
docker run --restart=always <image>
docker run --restart=unless-stopped <image>

# Copy files to/from container
docker cp <file> <container>:<path>
docker cp <container>:<path> <file>
```

## 🏷️ Image Tags Best Practices
```bash
# Specific versions (recommended)
nginx:1.21-alpine
postgres:13.4
node:16.14.0-alpine

# Major versions (acceptable)
nginx:1.21
postgres:13
node:16

# Avoid (unpredictable)
nginx:latest
postgres:latest
node:latest
```

## 🚨 Troubleshooting
```bash
# Container won't start
docker logs <container>
docker inspect <container> | grep -i error

# Permission issues
docker exec -it <container> ls -la <path>
docker exec -u root -it <container> bash

# Port conflicts
docker ps --format "table {{.Names}}\t{{.Ports}}"
netstat -tlnp | grep <port>

# Disk space issues
docker system df
docker system prune -a

# Network connectivity
docker exec <container> ping <target>
docker exec <container> nslookup <hostname>
docker network inspect <network>
```

## ⚡ Quick One-Liners
```bash
# Stop all running containers
docker stop $(docker ps -q)

# Remove all stopped containers
docker rm $(docker ps -aq --filter status=exited)

# Remove all images with <none> tag
docker rmi $(docker images -f "dangling=true" -q)

# Show container resource usage
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# Show containers with their images
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"

# Get container IP addresses
docker inspect $(docker ps -q) | grep IPAddress
```

---

## 📚 Exit Codes
- `0` - Success
- `125` - Docker daemon error
- `126` - Container command not executable
- `127` - Container command not found
- `128+n` - Container killed by signal n

---

**💡 Pro Tip**: Create aliases for frequently used commands in your `~/.bashrc`:
```bash
alias dps='docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"'
alias di='docker images'
alias dlogs='docker logs -f'
alias dexec='docker exec -it'
alias dclean='docker system prune -f'
```