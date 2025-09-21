#!/bin/bash
# Module 5: Enterprise Security & Compliance - Demo Script

set -e

echo "🔒 MODULE 5: ENTERPRISE SECURITY & COMPLIANCE DEMO"
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

# Demo 1: Secure Image Building
print_header "Demo 1: Building Security-Hardened Images"

echo "Creating a vulnerable application for demonstration..."
cat > vulnerable-app.py << 'EOF'
from flask import Flask, request
import os
import subprocess

app = Flask(__name__)

@app.route('/')
def home():
    return "Vulnerable App Running"

@app.route('/execute')
def execute():
    # VULNERABILITY: Command injection
    cmd = request.args.get('cmd', 'ls')
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return f"Output: {result.stdout}"

@app.route('/file')
def read_file():
    # VULNERABILITY: Path traversal
    filename = request.args.get('file', '/etc/passwd')
    try:
        with open(filename, 'r') as f:
            return f.read()
    except:
        return "File not found"

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
EOF

echo "Creating insecure Dockerfile..."
cat > Dockerfile.insecure << 'EOF'
FROM ubuntu:latest

# Running as root (BAD)
WORKDIR /app

# Installing unnecessary packages (BAD)
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    curl \
    wget \
    vim \
    ssh \
    telnet \
    netcat

# Copying everything (BAD)
COPY . .

# Installing with cache (BAD)
RUN pip3 install flask

# Exposing as root (BAD)
EXPOSE 5000

CMD ["python3", "vulnerable-app.py"]
EOF

echo "Creating secure Dockerfile..."
cat > Dockerfile.secure << 'EOF'
# Multi-stage build for security
FROM python:3.11-alpine AS builder

# Install only necessary packages
RUN apk add --no-cache gcc musl-dev

# Create virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Production stage with minimal base
FROM python:3.11-alpine AS production

# Create non-root user
RUN addgroup -g 1001 -S appgroup && \
    adduser -S -u 1001 -h /app -s /sbin/nologin -G appgroup appuser

# Copy virtual environment from builder
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Set working directory
WORKDIR /app

# Copy application files with proper ownership
COPY --chown=appuser:appgroup secure-app.py .

# Switch to non-root user
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:5000/health')" || exit 1

# Security-hardened run
EXPOSE 5000

CMD ["python", "secure-app.py"]
EOF

echo "Creating secure application..."
cat > secure-app.py << 'EOF'
from flask import Flask, jsonify
import os
import logging

app = Flask(__name__)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@app.route('/')
def home():
    logger.info("Home endpoint accessed")
    return jsonify({"message": "Secure App Running", "version": "1.0"})

@app.route('/health')
def health():
    return jsonify({"status": "healthy"})

@app.route('/info')
def info():
    # Only return safe information
    safe_info = {
        "user": os.getenv("USER", "unknown"),
        "python_version": "3.11",
        "app_version": "1.0"
    }
    return jsonify(safe_info)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
EOF

cat > requirements.txt << 'EOF'
flask==2.3.3
requests==2.31.0
EOF

print_success "Created secure and insecure application examples"

# Build both images for comparison
echo "Building insecure image..."
if docker build -f Dockerfile.insecure -t insecure-app:latest . 2>/dev/null; then
    print_success "Built insecure image"
else
    print_warning "Docker not available - showing example output"
fi

echo "Building secure image..."
if docker build -f Dockerfile.secure -t secure-app:latest . 2>/dev/null; then
    print_success "Built secure image"
else
    print_warning "Docker not available - showing example output"
fi

# Demo 2: Container Security Scanning
print_header "Demo 2: Vulnerability Scanning"

echo "Creating vulnerability scanning script..."
cat > scan-images.sh << 'EOF'
#!/bin/bash

# Simulated vulnerability scan results
echo "Security Scan Report"
echo "==================="

echo ""
echo "INSECURE IMAGE SCAN RESULTS:"
echo "----------------------------"
echo "❌ CRITICAL: 15 vulnerabilities found"
echo "❌ HIGH: 42 vulnerabilities found"
echo "❌ MEDIUM: 128 vulnerabilities found"
echo "❌ LOW: 67 vulnerabilities found"
echo ""
echo "Critical Issues:"
echo "- CVE-2023-1234: Remote code execution in base Ubuntu image"
echo "- CVE-2023-5678: Privilege escalation in SSH package"
echo "- CVE-2023-9012: Buffer overflow in telnet package"
echo ""

echo "SECURE IMAGE SCAN RESULTS:"
echo "-------------------------"
echo "✅ CRITICAL: 0 vulnerabilities found"
echo "✅ HIGH: 1 vulnerabilities found"
echo "⚠️  MEDIUM: 3 vulnerabilities found"
echo "ℹ️  LOW: 5 vulnerabilities found"
echo ""
echo "Remaining Issues:"
echo "- CVE-2023-3456: Minor issue in base Alpine image (fix available)"
echo ""

echo "RECOMMENDATIONS:"
echo "- Use distroless or minimal base images"
echo "- Remove unnecessary packages"
echo "- Run as non-root user"
echo "- Regular security updates"
EOF

chmod +x scan-images.sh
./scan-images.sh

print_success "Vulnerability scanning demonstration completed"

# Demo 3: Runtime Security Configuration
print_header "Demo 3: Secure Container Runtime Configuration"

echo "Creating secure deployment script..."
cat > deploy-secure.sh << 'EOF'
#!/bin/bash

echo "Deploying container with security hardening..."

# Security-hardened deployment command
DEPLOY_CMD="docker run -d \\
  --name secure-web-app \\
  --read-only \\
  --tmpfs /tmp:rw,noexec,nosuid,size=50m \\
  --cap-drop=ALL \\
  --cap-add=NET_BIND_SERVICE \\
  --security-opt=no-new-privileges:true \\
  --user 1001:1001 \\
  --ulimit nofile=1024:2048 \\
  --ulimit nproc=50 \\
  --memory=256m \\
  --cpus=0.5 \\
  --restart=unless-stopped \\
  --network=secure-network \\
  --publish 8080:5000 \\
  secure-app:latest"

echo "Deployment command:"
echo "$DEPLOY_CMD"

echo ""
echo "Security features enabled:"
echo "✅ Read-only filesystem"
echo "✅ Temporary filesystem in memory"
echo "✅ All capabilities dropped"
echo "✅ Only NET_BIND_SERVICE capability added"
echo "✅ No privilege escalation"
echo "✅ Non-root user (1001:1001)"
echo "✅ Resource limits (CPU: 0.5, Memory: 256MB)"
echo "✅ Process limits (max 50 processes)"
echo "✅ File descriptor limits"
echo "✅ Automatic restart policy"
echo "✅ Network isolation"
EOF

chmod +x deploy-secure.sh
./deploy-secure.sh

print_success "Secure deployment configuration demonstrated"

# Demo 4: Secrets Management
print_header "Demo 4: Docker Secrets Management"

echo "Creating secrets management demonstration..."

# Create dummy secrets
echo "Creating example secrets..."
echo "super-secret-password-123" > db_password.txt
echo "api-key-abcd-1234-efgh-5678" > api_key.txt

echo "Docker Swarm secrets example:"
cat > swarm-secrets-demo.sh << 'EOF'
#!/bin/bash

echo "Initializing Docker Swarm..."
# docker swarm init

echo "Creating secrets..."
# docker secret create db_password db_password.txt
# docker secret create api_key api_key.txt

echo "Deploying service with secrets..."
cat > docker-compose.secrets.yml << 'COMPOSE_EOF'
version: '3.8'

services:
  web:
    image: secure-app:latest
    secrets:
      - db_password
      - api_key
    environment:
      - DB_PASSWORD_FILE=/run/secrets/db_password
      - API_KEY_FILE=/run/secrets/api_key
    deploy:
      replicas: 2
      restart_policy:
        condition: on-failure

secrets:
  db_password:
    external: true
  api_key:
    external: true
COMPOSE_EOF

echo "Service would access secrets from:"
echo "- /run/secrets/db_password"
echo "- /run/secrets/api_key"

echo ""
echo "Application code for reading secrets:"
cat > secret-reader.py << 'SECRET_EOF'
import os

def read_secret(secret_name):
    """Securely read secret from file"""
    secret_file = f"/run/secrets/{secret_name}"
    if os.path.exists(secret_file):
        with open(secret_file, 'r') as f:
            return f.read().strip()
    # Fallback to environment variable
    return os.getenv(secret_name.upper())

# Usage
db_password = read_secret('db_password')
api_key = read_secret('api_key')

print(f"Database password loaded: {'*' * len(db_password) if db_password else 'Not found'}")
print(f"API key loaded: {'*' * len(api_key) if api_key else 'Not found'}")
SECRET_EOF

echo "Created secret management example"
EOF

chmod +x swarm-secrets-demo.sh
./swarm-secrets-demo.sh

print_success "Secrets management demonstration completed"

# Demo 5: Compliance Configuration
print_header "Demo 5: Compliance Framework Implementation"

echo "Creating GDPR compliance example..."
cat > gdpr-compliance.py << 'EOF'
import hashlib
import json
import os
from datetime import datetime, timedelta

class GDPRCompliantApp:
    def __init__(self):
        self.encryption_key = os.getenv('ENCRYPTION_KEY', 'default-key-change-me')
        self.data_retention_days = int(os.getenv('DATA_RETENTION_DAYS', '365'))
        
    def pseudonymize_data(self, personal_id):
        """Pseudonymize personal identifiers for GDPR compliance"""
        salt = os.getenv('GDPR_SALT', 'gdpr-salt-2023')
        return hashlib.sha256(f"{personal_id}{salt}".encode()).hexdigest()[:16]
    
    def log_data_processing(self, purpose, legal_basis, data_subject):
        """Log data processing activity for audit trail"""
        log_entry = {
            "timestamp": datetime.utcnow().isoformat(),
            "event": "personal_data_processing",
            "purpose": purpose,
            "legal_basis": legal_basis,
            "data_subject": self.pseudonymize_data(data_subject),
            "retention_until": (datetime.utcnow() + timedelta(days=self.data_retention_days)).isoformat()
        }
        
        # In production, send to secure logging system
        print(f"GDPR Audit Log: {json.dumps(log_entry, indent=2)}")
        
    def handle_data_subject_request(self, request_type, subject_id):
        """Handle GDPR data subject rights"""
        print(f"Processing {request_type} request for subject: {self.pseudonymize_data(subject_id)}")
        
        if request_type == "access":
            return {"message": "Personal data export prepared", "format": "JSON"}
        elif request_type == "deletion":
            return {"message": "Personal data deletion completed", "confirmation": "DEL-2023-001"}
        elif request_type == "portability":
            return {"message": "Data portability package prepared", "format": "JSON"}

# Example usage
app = GDPRCompliantApp()
app.log_data_processing(
    purpose="user_authentication",
    legal_basis="contract",
    data_subject="user123@example.com"
)

result = app.handle_data_subject_request("deletion", "user123@example.com")
print(f"Request result: {result}")
EOF

echo "Creating PCI-DSS compliance example..."
cat > pci-dss-compliance.sh << 'EOF'
#!/bin/bash

echo "PCI-DSS Compliant Container Configuration"
echo "========================================"

echo ""
echo "Network Segmentation (Requirement 1):"
echo "- Isolated network for payment processing"
echo "- Firewall rules restricting access"
echo "- DMZ deployment for web applications"

echo ""
echo "Data Protection (Requirement 3):"
echo "- All cardholder data encrypted with AES-256"
echo "- Encryption keys stored in HSM"
echo "- No storage of sensitive authentication data"

echo ""
echo "Access Control (Requirement 7):"
echo "- Role-based access control implemented"
echo "- Least privilege principle enforced"
echo "- Multi-factor authentication required"

echo ""
echo "Secure Networks (Requirement 1 & 2):"
docker_cmd="docker run -d \\
  --name pci-payment-app \\
  --network pci-secure-network \\
  --read-only \\
  --cap-drop=ALL \\
  --security-opt=no-new-privileges:true \\
  --user 2000:2000 \\
  --memory=512m \\
  --cpus=1.0 \\
  --log-driver=syslog \\
  --log-opt syslog-address=tcp://secure-log-server:514 \\
  --secret source=card_encryption_key,target=/run/secrets/card_key \\
  pci-compliant-app:latest"

echo "$docker_cmd"

echo ""
echo "Monitoring & Logging (Requirement 10):"
echo "- All payment transactions logged"
echo "- Log integrity protection enabled"
echo "- Real-time monitoring for anomalies"
echo "- Centralized log management"

echo ""
echo "Vulnerability Management (Requirement 6):"
echo "- Regular security scans"
echo "- Automated patch management"
echo "- Secure development lifecycle"
echo "- Code review processes"
EOF

chmod +x pci-dss-compliance.sh
./pci-dss-compliance.sh

print_success "Compliance framework demonstrations completed"

# Demo 6: Security Monitoring and Alerting
print_header "Demo 6: Runtime Security Monitoring"

echo "Creating security monitoring script..."
cat > security-monitor.sh << 'EOF'
#!/bin/bash

# Simulated security monitoring
echo "Container Security Monitoring Dashboard"
echo "======================================"

echo ""
echo "Real-time Security Alerts:"
echo "--------------------------"
echo "🟢 [00:15:23] Container 'web-app-1' - Normal behavior detected"
echo "🟡 [00:15:45] Container 'web-app-2' - Unusual network activity (investigating)"
echo "🟢 [00:16:12] Container 'db-primary' - Health check passed"
echo "🔴 [00:16:34] Container 'api-service' - ALERT: Privilege escalation attempt blocked"
echo "🟢 [00:16:55] Container 'cache-redis' - Resource usage within limits"

echo ""
echo "Security Metrics (Last 24h):"
echo "----------------------------"
echo "• Failed login attempts: 23 (normal)"
echo "• Blocked malicious requests: 156"
echo "• Container restarts: 2 (planned maintenance)"
echo "• Security policy violations: 0"
echo "• Vulnerability scans passed: 12/12"

echo ""
echo "Compliance Status:"
echo "-----------------"
echo "✅ GDPR: All personal data processing logged"
echo "✅ PCI-DSS: Encryption standards met"
echo "✅ SOC2: Access controls enforced"
echo "✅ HIPAA: PHI protection validated"

echo ""
echo "Automated Responses:"
echo "-------------------"
echo "• Blocked 45 suspicious IP addresses"
echo "• Quarantined 3 containers with anomalous behavior"
echo "• Triggered incident response for critical alert"
echo "• Updated security policies based on threat intelligence"

echo ""
echo "Recommendations:"
echo "---------------"
echo "• Review container 'web-app-2' network connections"
echo "• Update base images for 3 containers"
echo "• Rotate API keys for external services"
echo "• Schedule penetration testing for next week"
EOF

chmod +x security-monitor.sh
./security-monitor.sh

print_success "Security monitoring demonstration completed"

# Demo 7: Incident Response
print_header "Demo 7: Security Incident Response"

echo "Creating incident response playbook..."
cat > incident-response.sh << 'EOF'
#!/bin/bash

echo "Security Incident Response Playbook"
echo "==================================="

echo ""
echo "Incident Classification:"
echo "-----------------------"
echo "🔴 CRITICAL: Container compromise detected"
echo "📍 Affected: web-app-3 (Container ID: abc123def456)"
echo "⏰ Detected: $(date)"
echo "🎯 Impact: Potential data exposure"

echo ""
echo "Immediate Response Actions:"
echo "--------------------------"

echo "1. Container Isolation:"
echo "   docker network disconnect production-network web-app-3"
echo "   docker pause web-app-3"

echo ""
echo "2. Evidence Collection:"
echo "   docker logs web-app-3 > incident-logs-$(date +%Y%m%d-%H%M%S).txt"
echo "   docker exec web-app-3 ps aux > process-list.txt"
echo "   docker exec web-app-3 netstat -tuln > network-connections.txt"

echo ""
echo "3. Forensic Analysis:"
echo "   # Create forensic image"
echo "   docker commit web-app-3 forensic-image:$(date +%Y%m%d-%H%M%S)"
echo "   # Export for analysis"
echo "   docker save forensic-image:latest > forensic-evidence.tar"

echo ""
echo "4. Containment:"
echo "   # Stop compromised container"
echo "   docker stop web-app-3"
echo "   # Deploy clean backup"
echo "   docker run -d --name web-app-3-clean backup-image:latest"

echo ""
echo "5. Communication:"
echo "   # Notify stakeholders"
echo "   # Update incident tracking system"
echo "   # Prepare communication for customers (if required)"

echo ""
echo "Recovery Actions:"
echo "----------------"
echo "✅ Clean container deployed"
echo "✅ Security patches applied"
echo "✅ Monitoring enhanced"
echo "✅ Access logs reviewed"
echo "✅ Vulnerability assessment scheduled"

echo ""
echo "Post-Incident Analysis:"
echo "----------------------"
echo "• Root cause: Unpatched vulnerability in base image"
echo "• Lessons learned: Implement automated security scanning"
echo "• Process improvements: Enhanced monitoring rules"
echo "• Prevention measures: Mandatory security reviews"
EOF

chmod +x incident-response.sh
./incident-response.sh

print_success "Incident response demonstration completed"

# Demo Summary
print_header "Demo Summary and Next Steps"

echo "Module 5 Security Demonstrations Completed!"
echo ""
echo "Topics Covered:"
echo "✅ Secure image building and hardening"
echo "✅ Vulnerability scanning and assessment"
echo "✅ Runtime security configuration"
echo "✅ Secrets management"
echo "✅ Compliance framework implementation"
echo "✅ Security monitoring and alerting"
echo "✅ Incident response procedures"

echo ""
echo "Files Created:"
echo "• vulnerable-app.py - Example vulnerable application"
echo "• secure-app.py - Security-hardened application"
echo "• Dockerfile.secure - Hardened container build"
echo "• scan-images.sh - Vulnerability scanning demo"
echo "• deploy-secure.sh - Secure deployment configuration"
echo "• swarm-secrets-demo.sh - Secrets management example"
echo "• gdpr-compliance.py - GDPR compliance implementation"
echo "• pci-dss-compliance.sh - PCI-DSS configuration"
echo "• security-monitor.sh - Security monitoring dashboard"
echo "• incident-response.sh - Incident response playbook"

echo ""
echo "🎯 Key Takeaways:"
echo "1. Security must be built into every layer"
echo "2. Regular vulnerability scanning is essential"
echo "3. Compliance requires systematic implementation"
echo "4. Monitoring and response capabilities are critical"
echo "5. Security is an ongoing process, not a one-time task"

echo ""
echo "Ready for Module 6: Production Deployment Strategies!"
print_success "Module 5 demonstrations completed successfully!"