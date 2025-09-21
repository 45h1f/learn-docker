# Module 5: Enterprise Security & Compliance - Exercises

## 🎯 Exercise Overview

These hands-on exercises will help you master enterprise-level container security, compliance frameworks, and security monitoring. Each exercise builds upon the previous one to create a comprehensive security-hardened environment.

---

## Exercise 1: Security-Hardened Application Deployment 🔒

**Objective**: Create and deploy a security-hardened web application following enterprise best practices.

### Task 1.1: Secure Application Development
Create a Flask application with security controls:

```python
# secure_web_app.py
from flask import Flask, request, jsonify, session
from werkzeug.security import generate_password_hash, check_password_hash
import secrets
import os
import logging
from datetime import datetime
import re

app = Flask(__name__)
app.secret_key = os.getenv('SECRET_KEY', secrets.token_hex(32))

# Configure secure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Security headers middleware
@app.after_request
def add_security_headers(response):
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['X-Frame-Options'] = 'DENY'
    response.headers['X-XSS-Protection'] = '1; mode=block'
    response.headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains'
    response.headers['Content-Security-Policy'] = "default-src 'self'"
    return response

# Input validation
def validate_input(data, pattern):
    return re.match(pattern, data) is not None

@app.route('/')
def home():
    logger.info(f"Home page accessed from {request.remote_addr}")
    return jsonify({
        "message": "Secure Enterprise Application",
        "version": "1.0",
        "security": "enabled"
    })

@app.route('/health')
def health():
    return jsonify({"status": "healthy", "timestamp": datetime.utcnow().isoformat()})

@app.route('/api/data')
def get_data():
    # Validate request headers
    if 'X-API-Key' not in request.headers:
        logger.warning(f"Unauthorized API access attempt from {request.remote_addr}")
        return jsonify({"error": "Missing API key"}), 401
    
    logger.info("Secure data endpoint accessed")
    return jsonify({
        "data": "This is secure enterprise data",
        "user": session.get('user', 'anonymous'),
        "timestamp": datetime.utcnow().isoformat()
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```

### Task 1.2: Create Multi-Stage Security-Hardened Dockerfile

```dockerfile
# Dockerfile.enterprise
# Stage 1: Security scanning and dependency analysis
FROM python:3.11-alpine AS security-scan
WORKDIR /app
COPY requirements.txt .

# Install security tools
RUN pip install safety bandit

# Security scans
COPY . .
RUN safety check -r requirements.txt || true
RUN bandit -r . -f json -o bandit-report.json || true

# Stage 2: Build stage
FROM python:3.11-alpine AS builder
WORKDIR /app

# Install build dependencies
RUN apk add --no-cache gcc musl-dev libffi-dev

# Create virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Stage 3: Production stage with security hardening
FROM python:3.11-alpine AS production

# Install security packages
RUN apk add --no-cache dumb-init && \
    rm -rf /var/cache/apk/*

# Create dedicated user and group
RUN addgroup -g 2000 -S appgroup && \
    adduser -S -u 2000 -h /app -s /sbin/nologin -G appgroup appuser

# Copy virtual environment from builder
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Set working directory
WORKDIR /app

# Copy application files with proper ownership
COPY --chown=appuser:appgroup secure_web_app.py .
COPY --chown=appuser:appgroup static/ ./static/
COPY --chown=appuser:appgroup templates/ ./templates/

# Create logs directory
RUN mkdir -p /app/logs && chown appuser:appgroup /app/logs

# Switch to non-root user
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:5000/health', timeout=5)" || exit 1

# Security labels
LABEL security.scan="completed" \
      security.level="enterprise" \
      maintainer="security-team@company.com"

# Use dumb-init for proper signal handling
ENTRYPOINT ["/usr/bin/dumb-init", "--"]

EXPOSE 5000

CMD ["python", "secure_web_app.py"]
```

### Task 1.3: Secure Deployment Script

Create a deployment script with security hardening:

```bash
#!/bin/bash
# secure-deploy.sh

set -euo pipefail

IMAGE_NAME="secure-enterprise-app:latest"
CONTAINER_NAME="secure-web-app"
NETWORK_NAME="enterprise-secure-network"

echo "🔒 Deploying security-hardened application..."

# Create secure network if it doesn't exist
if ! docker network ls | grep -q "$NETWORK_NAME"; then
    docker network create \
        --driver bridge \
        --subnet=172.20.0.0/16 \
        --opt com.docker.network.bridge.enable_icc=false \
        "$NETWORK_NAME"
fi

# Deploy with security hardening
docker run -d \
    --name "$CONTAINER_NAME" \
    --network "$NETWORK_NAME" \
    --read-only \
    --tmpfs /tmp:rw,noexec,nosuid,nodev,size=50m \
    --tmpfs /app/logs:rw,size=10m \
    --cap-drop=ALL \
    --cap-add=NET_BIND_SERVICE \
    --security-opt=no-new-privileges:true \
    --security-opt=apparmor:docker-default \
    --user 2000:2000 \
    --ulimit nofile=1024:2048 \
    --ulimit nproc=50 \
    --memory=512m \
    --cpus=1.0 \
    --restart=unless-stopped \
    --publish 8443:5000 \
    --env SECRET_KEY="$(openssl rand -hex 32)" \
    --env FLASK_ENV=production \
    "$IMAGE_NAME"

echo "✅ Secure application deployed successfully!"
```

**Deliverables**:
- [ ] Secure Flask application with input validation and security headers
- [ ] Multi-stage Dockerfile with security scanning
- [ ] Deployment script with runtime security hardening
- [ ] Documentation of security measures implemented

---

## Exercise 2: Vulnerability Scanning and Assessment 🔍

**Objective**: Implement comprehensive vulnerability scanning pipeline for container images and running containers.

### Task 2.1: Automated Vulnerability Scanning Pipeline

Create a comprehensive scanning script:

```bash
#!/bin/bash
# vulnerability-scanner.sh

set -euo pipefail

IMAGE_NAME=$1
SCAN_RESULTS_DIR="./scan-results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$SCAN_RESULTS_DIR"

echo "🔍 Starting comprehensive vulnerability scan for $IMAGE_NAME"

# Function to check if tool is available
check_tool() {
    if ! command -v "$1" &> /dev/null; then
        echo "⚠️  $1 not found. Please install it to run this scan."
        return 1
    fi
    return 0
}

# Docker Scout scan
echo "Running Docker Scout scan..."
if check_tool docker; then
    docker scout cves --format json "$IMAGE_NAME" > "$SCAN_RESULTS_DIR/scout_${TIMESTAMP}.json" 2>/dev/null || \
    echo "Docker Scout not available or image not found"
fi

# Trivy scan
echo "Running Trivy scan..."
if check_tool trivy; then
    trivy image --format json --output "$SCAN_RESULTS_DIR/trivy_${TIMESTAMP}.json" "$IMAGE_NAME"
    trivy image --format table --severity HIGH,CRITICAL "$IMAGE_NAME" > "$SCAN_RESULTS_DIR/trivy_summary_${TIMESTAMP}.txt"
fi

# Grype scan (if available)
echo "Running Grype scan..."
if check_tool grype; then
    grype "$IMAGE_NAME" -o json > "$SCAN_RESULTS_DIR/grype_${TIMESTAMP}.json"
fi

# Analyze results
echo "Analyzing scan results..."
python3 << 'EOF'
import json
import os
from datetime import datetime

scan_dir = "./scan-results"
timestamp = os.environ.get('TIMESTAMP', 'latest')

def analyze_trivy_results(filename):
    try:
        with open(filename, 'r') as f:
            data = json.load(f)
        
        if not data.get('Results'):
            return {"critical": 0, "high": 0, "medium": 0, "low": 0}
        
        severity_count = {"critical": 0, "high": 0, "medium": 0, "low": 0}
        
        for result in data['Results']:
            if 'Vulnerabilities' in result:
                for vuln in result['Vulnerabilities']:
                    severity = vuln.get('Severity', '').lower()
                    if severity in severity_count:
                        severity_count[severity] += 1
        
        return severity_count
    except (FileNotFoundError, json.JSONDecodeError, KeyError):
        return {"critical": 0, "high": 0, "medium": 0, "low": 0}

# Analyze Trivy results
trivy_file = f"{scan_dir}/trivy_{timestamp}.json"
trivy_results = analyze_trivy_results(trivy_file)

# Generate report
report = {
    "scan_timestamp": datetime.now().isoformat(),
    "image": os.environ.get('IMAGE_NAME', 'unknown'),
    "vulnerability_summary": trivy_results,
    "risk_score": trivy_results['critical'] * 10 + trivy_results['high'] * 3 + trivy_results['medium'] * 1
}

print("=" * 60)
print("VULNERABILITY SCAN REPORT")
print("=" * 60)
print(f"Image: {report['image']}")
print(f"Scan Time: {report['scan_timestamp']}")
print(f"Risk Score: {report['risk_score']}")
print()
print("Vulnerability Summary:")
print(f"  Critical: {trivy_results['critical']}")
print(f"  High:     {trivy_results['high']}")
print(f"  Medium:   {trivy_results['medium']}")
print(f"  Low:      {trivy_results['low']}")
print()

if report['risk_score'] > 50:
    print("🚨 HIGH RISK: Immediate action required!")
elif report['risk_score'] > 20:
    print("⚠️  MEDIUM RISK: Review and remediate")
else:
    print("✅ LOW RISK: Acceptable for deployment")

# Save detailed report
with open(f"{scan_dir}/vulnerability_report_{timestamp}.json", 'w') as f:
    json.dump(report, f, indent=2)

print(f"\nDetailed report saved to: {scan_dir}/vulnerability_report_{timestamp}.json")
EOF

echo "🔍 Vulnerability scanning completed!"
```

### Task 2.2: Container Runtime Security Monitoring

Create a runtime security monitoring script:

```bash
#!/bin/bash
# runtime-security-monitor.sh

CONTAINER_NAME=$1
MONITORING_DURATION=${2:-300}  # Default 5 minutes

echo "🔍 Starting runtime security monitoring for $CONTAINER_NAME"

# Monitor suspicious processes
monitor_processes() {
    echo "Monitoring processes..."
    timeout "$MONITORING_DURATION" bash -c "
        while true; do
            echo \"[$(date)] Process monitor:\"
            docker exec $CONTAINER_NAME ps aux | grep -E '(bash|sh|nc|wget|curl|ssh)' | grep -v grep || true
            sleep 30
        done
    " > process-monitor.log &
}

# Monitor network connections
monitor_network() {
    echo "Monitoring network connections..."
    timeout "$MONITORING_DURATION" bash -c "
        while true; do
            echo \"[$(date)] Network monitor:\"
            docker exec $CONTAINER_NAME netstat -tuln 2>/dev/null | grep -v 127.0.0.1 || true
            sleep 30
        done
    " > network-monitor.log &
}

# Monitor file system changes
monitor_filesystem() {
    echo "Monitoring file system..."
    if docker exec "$CONTAINER_NAME" which inotifywait >/dev/null 2>&1; then
        timeout "$MONITORING_DURATION" docker exec "$CONTAINER_NAME" \
            inotifywait -m -r /app -e modify,create,delete,move > filesystem-monitor.log &
    else
        echo "inotifywait not available in container"
    fi
}

# Start monitoring
monitor_processes
monitor_network
monitor_filesystem

echo "Monitoring started. Duration: ${MONITORING_DURATION} seconds"
sleep "$MONITORING_DURATION"

# Analyze results
echo "Analyzing monitoring results..."
python3 << 'EOF'
import re
from datetime import datetime

def analyze_process_log():
    suspicious_processes = []
    try:
        with open('process-monitor.log', 'r') as f:
            content = f.read()
            
        # Look for suspicious patterns
        suspicious_patterns = [
            r'bash.*-c',  # Command execution
            r'sh.*-c',    # Shell execution
            r'nc.*-l',    # Netcat listener
            r'wget.*http', # File downloads
            r'curl.*http', # HTTP requests
            r'ssh.*@'     # SSH connections
        ]
        
        for pattern in suspicious_patterns:
            matches = re.findall(pattern, content, re.IGNORECASE)
            if matches:
                suspicious_processes.extend(matches)
                
    except FileNotFoundError:
        pass
    
    return suspicious_processes

def analyze_network_log():
    unusual_connections = []
    try:
        with open('network-monitor.log', 'r') as f:
            content = f.read()
            
        # Look for unusual ports
        unusual_ports = ['22', '23', '135', '139', '445', '3389', '4444', '6666']
        for port in unusual_ports:
            if f':{port}' in content:
                unusual_connections.append(f"Port {port} activity detected")
                
    except FileNotFoundError:
        pass
    
    return unusual_connections

# Generate security report
suspicious_procs = analyze_process_log()
unusual_nets = analyze_network_log()

print("RUNTIME SECURITY ANALYSIS REPORT")
print("=" * 50)
print(f"Analysis Time: {datetime.now().isoformat()}")
print()

if suspicious_procs:
    print("⚠️  SUSPICIOUS PROCESSES DETECTED:")
    for proc in suspicious_procs[:5]:  # Show first 5
        print(f"  - {proc}")
    print()

if unusual_nets:
    print("⚠️  UNUSUAL NETWORK ACTIVITY:")
    for net in unusual_nets:
        print(f"  - {net}")
    print()

if not suspicious_procs and not unusual_nets:
    print("✅ No suspicious activity detected during monitoring period")

# Calculate risk score
risk_score = len(suspicious_procs) * 2 + len(unusual_nets) * 3

print(f"Runtime Risk Score: {risk_score}")
if risk_score > 10:
    print("🚨 HIGH RISK: Investigate immediately!")
elif risk_score > 5:
    print("⚠️  MEDIUM RISK: Review activity")
else:
    print("✅ LOW RISK: Normal behavior")
EOF

echo "✅ Runtime security monitoring completed!"
```

**Deliverables**:
- [ ] Automated vulnerability scanning pipeline
- [ ] Runtime security monitoring system
- [ ] Risk assessment reports
- [ ] Remediation recommendations

---

## Exercise 3: Secrets Management and Compliance 🔐

**Objective**: Implement enterprise-grade secrets management and compliance controls.

### Task 3.1: Docker Swarm Secrets Implementation

```bash
#!/bin/bash
# setup-swarm-secrets.sh

echo "🔐 Setting up Docker Swarm secrets management..."

# Initialize swarm if not already done
if ! docker info | grep -q "Swarm: active"; then
    echo "Initializing Docker Swarm..."
    docker swarm init
fi

# Create secrets
echo "Creating application secrets..."

# Database credentials
echo "postgres_user_$(openssl rand -hex 8)" | docker secret create db_username -
echo "$(openssl rand -base64 32)" | docker secret create db_password -

# API keys
echo "$(openssl rand -hex 32)" | docker secret create api_key -
echo "$(openssl rand -hex 16)" | docker secret create encryption_key -

# SSL certificates (for demo)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout temp_ssl.key -out temp_ssl.crt \
    -subj "/C=US/ST=CA/L=SF/O=Company/CN=app.company.com"

docker secret create ssl_certificate temp_ssl.crt
docker secret create ssl_private_key temp_ssl.key

# Clean up temporary files
rm temp_ssl.key temp_ssl.crt

echo "✅ Secrets created successfully!"
docker secret ls
```

### Task 3.2: Secrets-Aware Application

```python
# secrets_aware_app.py
import os
import json
import hashlib
from flask import Flask, jsonify, request
from datetime import datetime
import logging

app = Flask(__name__)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class SecureSecretsManager:
    def __init__(self):
        self.secrets_path = "/run/secrets"
        self.env_fallback = True
        
    def get_secret(self, secret_name):
        """Securely retrieve secret from file or environment"""
        # Try to read from Docker secret first
        secret_file = os.path.join(self.secrets_path, secret_name)
        
        if os.path.exists(secret_file):
            try:
                with open(secret_file, 'r') as f:
                    secret_value = f.read().strip()
                logger.info(f"Secret '{secret_name}' loaded from file")
                return secret_value
            except Exception as e:
                logger.error(f"Error reading secret file {secret_name}: {e}")
        
        # Fallback to environment variable
        if self.env_fallback:
            env_var = f"{secret_name.upper()}"
            secret_value = os.getenv(env_var)
            if secret_value:
                logger.info(f"Secret '{secret_name}' loaded from environment")
                return secret_value
        
        logger.warning(f"Secret '{secret_name}' not found")
        return None
    
    def validate_secret(self, secret_name, min_length=8):
        """Validate secret meets security requirements"""
        secret = self.get_secret(secret_name)
        if not secret:
            return False, "Secret not found"
        
        if len(secret) < min_length:
            return False, f"Secret too short (minimum {min_length} characters)"
        
        return True, "Secret valid"

# Initialize secrets manager
secrets_manager = SecureSecretsManager()

@app.route('/')
def home():
    return jsonify({
        "message": "Secrets-Aware Enterprise Application",
        "secrets_loaded": check_secrets_status(),
        "timestamp": datetime.utcnow().isoformat()
    })

@app.route('/health')
def health():
    secrets_status = check_secrets_status()
    return jsonify({
        "status": "healthy" if secrets_status["all_loaded"] else "degraded",
        "secrets": secrets_status,
        "timestamp": datetime.utcnow().isoformat()
    })

def check_secrets_status():
    """Check status of all required secrets"""
    required_secrets = ['db_username', 'db_password', 'api_key', 'encryption_key']
    status = {}
    
    for secret_name in required_secrets:
        is_valid, message = secrets_manager.validate_secret(secret_name)
        status[secret_name] = {
            "loaded": is_valid,
            "message": message if not is_valid else "OK"
        }
    
    status["all_loaded"] = all(s["loaded"] for s in status.values())
    return status

@app.route('/api/secure-data')
def get_secure_data():
    """Endpoint that requires API key authentication"""
    provided_key = request.headers.get('X-API-Key')
    expected_key = secrets_manager.get_secret('api_key')
    
    if not expected_key:
        logger.error("API key secret not available")
        return jsonify({"error": "Service configuration error"}), 500
    
    if not provided_key or provided_key != expected_key:
        logger.warning(f"Invalid API key attempt from {request.remote_addr}")
        return jsonify({"error": "Invalid API key"}), 401
    
    # Use encryption key for data protection
    encryption_key = secrets_manager.get_secret('encryption_key')
    data_hash = hashlib.sha256(f"secure_data_{encryption_key}".encode()).hexdigest()[:16]
    
    return jsonify({
        "secure_data": "This is encrypted enterprise data",
        "data_hash": data_hash,
        "timestamp": datetime.utcnow().isoformat()
    })

@app.route('/api/database-status')
def database_status():
    """Simulate database connection using secrets"""
    db_user = secrets_manager.get_secret('db_username')
    db_pass = secrets_manager.get_secret('db_password')
    
    if not db_user or not db_pass:
        return jsonify({"error": "Database credentials not available"}), 500
    
    # Simulate database connection (don't log actual credentials)
    return jsonify({
        "database": "connected",
        "user": f"{db_user[:4]}***",  # Partially mask username
        "timestamp": datetime.utcnow().isoformat()
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```

### Task 3.3: GDPR Compliance Implementation

```python
# gdpr_compliance.py
import os
import json
import hashlib
import sqlite3
from datetime import datetime, timedelta
from flask import Flask, request, jsonify
import logging

app = Flask(__name__)
logger = logging.getLogger(__name__)

class GDPRComplianceManager:
    def __init__(self, db_path="/tmp/gdpr_audit.db"):
        self.db_path = db_path
        self.encryption_key = os.getenv('GDPR_ENCRYPTION_KEY', 'default-key')
        self.data_retention_days = int(os.getenv('DATA_RETENTION_DAYS', '365'))
        self.init_database()
    
    def init_database(self):
        """Initialize GDPR audit database"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS data_processing_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT NOT NULL,
                data_subject_id TEXT NOT NULL,
                purpose TEXT NOT NULL,
                legal_basis TEXT NOT NULL,
                data_types TEXT NOT NULL,
                retention_until TEXT NOT NULL,
                processor TEXT NOT NULL
            )
        ''')
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS consent_records (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                data_subject_id TEXT NOT NULL,
                purpose TEXT NOT NULL,
                consent_given BOOLEAN NOT NULL,
                consent_timestamp TEXT NOT NULL,
                consent_withdrawn BOOLEAN DEFAULT FALSE,
                withdrawal_timestamp TEXT
            )
        ''')
        
        conn.commit()
        conn.close()
    
    def pseudonymize_id(self, personal_id):
        """Pseudonymize personal identifier for GDPR compliance"""
        salt = os.getenv('GDPR_SALT', 'gdpr-salt-2023')
        return hashlib.sha256(f"{personal_id}{salt}".encode()).hexdigest()[:16]
    
    def log_data_processing(self, data_subject_id, purpose, legal_basis, data_types):
        """Log data processing activity for GDPR audit trail"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        retention_until = (datetime.utcnow() + timedelta(days=self.data_retention_days)).isoformat()
        pseudonymized_id = self.pseudonymize_id(data_subject_id)
        
        cursor.execute('''
            INSERT INTO data_processing_log 
            (timestamp, data_subject_id, purpose, legal_basis, data_types, retention_until, processor)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', (
            datetime.utcnow().isoformat(),
            pseudonymized_id,
            purpose,
            legal_basis,
            json.dumps(data_types),
            retention_until,
            'enterprise-app-v1.0'
        ))
        
        conn.commit()
        conn.close()
        
        logger.info(f"GDPR: Data processing logged for subject {pseudonymized_id}")
    
    def record_consent(self, data_subject_id, purpose, consent_given):
        """Record user consent for GDPR compliance"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        pseudonymized_id = self.pseudonymize_id(data_subject_id)
        
        cursor.execute('''
            INSERT INTO consent_records 
            (data_subject_id, purpose, consent_given, consent_timestamp)
            VALUES (?, ?, ?, ?)
        ''', (
            pseudonymized_id,
            purpose,
            consent_given,
            datetime.utcnow().isoformat()
        ))
        
        conn.commit()
        conn.close()
        
        logger.info(f"GDPR: Consent recorded for subject {pseudonymized_id}")
    
    def handle_data_subject_request(self, data_subject_id, request_type):
        """Handle GDPR data subject rights requests"""
        pseudonymized_id = self.pseudonymize_id(data_subject_id)
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        if request_type == "access":
            # Right to access
            cursor.execute('''
                SELECT purpose, legal_basis, data_types, timestamp, retention_until
                FROM data_processing_log 
                WHERE data_subject_id = ?
            ''', (pseudonymized_id,))
            
            processing_records = cursor.fetchall()
            
            cursor.execute('''
                SELECT purpose, consent_given, consent_timestamp, consent_withdrawn
                FROM consent_records 
                WHERE data_subject_id = ?
            ''', (pseudonymized_id,))
            
            consent_records = cursor.fetchall()
            
            conn.close()
            
            return {
                "request_type": "access",
                "data_subject": pseudonymized_id,
                "processing_activities": [
                    {
                        "purpose": record[0],
                        "legal_basis": record[1], 
                        "data_types": json.loads(record[2]),
                        "timestamp": record[3],
                        "retention_until": record[4]
                    } for record in processing_records
                ],
                "consent_records": [
                    {
                        "purpose": record[0],
                        "consent_given": bool(record[1]),
                        "timestamp": record[2],
                        "withdrawn": bool(record[3])
                    } for record in consent_records
                ]
            }
        
        elif request_type == "deletion":
            # Right to be forgotten
            cursor.execute('DELETE FROM data_processing_log WHERE data_subject_id = ?', (pseudonymized_id,))
            cursor.execute('DELETE FROM consent_records WHERE data_subject_id = ?', (pseudonymized_id,))
            
            deleted_count = cursor.rowcount
            conn.commit()
            conn.close()
            
            logger.info(f"GDPR: Data deletion completed for subject {pseudonymized_id}")
            
            return {
                "request_type": "deletion",
                "data_subject": pseudonymized_id,
                "status": "completed",
                "records_deleted": deleted_count,
                "confirmation_id": f"DEL-{datetime.utcnow().strftime('%Y%m%d')}-{pseudonymized_id[:8]}"
            }
        
        else:
            conn.close()
            return {"error": "Unsupported request type"}

# Initialize GDPR manager
gdpr_manager = GDPRComplianceManager()

@app.route('/gdpr/process-data', methods=['POST'])
def process_personal_data():
    """Process personal data with GDPR compliance"""
    data = request.json
    
    required_fields = ['data_subject_id', 'purpose', 'legal_basis', 'data_types']
    if not all(field in data for field in required_fields):
        return jsonify({"error": "Missing required fields"}), 400
    
    # Log the data processing activity
    gdpr_manager.log_data_processing(
        data['data_subject_id'],
        data['purpose'],
        data['legal_basis'],
        data['data_types']
    )
    
    return jsonify({
        "status": "success",
        "message": "Data processing logged for GDPR compliance",
        "timestamp": datetime.utcnow().isoformat()
    })

@app.route('/gdpr/consent', methods=['POST'])
def record_user_consent():
    """Record user consent"""
    data = request.json
    
    required_fields = ['data_subject_id', 'purpose', 'consent_given']
    if not all(field in data for field in required_fields):
        return jsonify({"error": "Missing required fields"}), 400
    
    gdpr_manager.record_consent(
        data['data_subject_id'],
        data['purpose'],
        data['consent_given']
    )
    
    return jsonify({
        "status": "success",
        "message": "Consent recorded",
        "timestamp": datetime.utcnow().isoformat()
    })

@app.route('/gdpr/data-subject-request', methods=['POST'])
def handle_data_subject_request():
    """Handle GDPR data subject rights requests"""
    data = request.json
    
    required_fields = ['data_subject_id', 'request_type']
    if not all(field in data for field in required_fields):
        return jsonify({"error": "Missing required fields"}), 400
    
    result = gdpr_manager.handle_data_subject_request(
        data['data_subject_id'],
        data['request_type']
    )
    
    return jsonify(result)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001)
```

**Deliverables**:
- [ ] Docker Swarm secrets implementation
- [ ] Secrets-aware application with proper secret handling
- [ ] GDPR compliance system with audit logging
- [ ] Consent management and data subject rights handling

---

## Exercise 4: Security Monitoring and Incident Response 🚨

**Objective**: Implement comprehensive security monitoring and automated incident response.

### Task 4.1: Advanced Security Monitoring Dashboard

```python
# security_monitoring.py
import json
import time
import random
from datetime import datetime, timedelta
from flask import Flask, jsonify, render_template_string
import threading
import sqlite3
from collections import defaultdict

app = Flask(__name__)

class SecurityMonitor:
    def __init__(self):
        self.alerts = []
        self.metrics = defaultdict(int)
        self.threat_score = 0
        self.containers = ["web-app-1", "web-app-2", "api-service", "db-primary", "cache-redis"]
        self.init_database()
        self.start_monitoring()
    
    def init_database(self):
        """Initialize security monitoring database"""
        conn = sqlite3.connect('/tmp/security_monitor.db', check_same_thread=False)
        cursor = conn.cursor()
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS security_events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT NOT NULL,
                event_type TEXT NOT NULL,
                severity TEXT NOT NULL,
                container_name TEXT,
                source_ip TEXT,
                description TEXT NOT NULL,
                threat_score INTEGER DEFAULT 0
            )
        ''')
        
        conn.commit()
        conn.close()
    
    def log_security_event(self, event_type, severity, container=None, source_ip=None, description="", threat_score=0):
        """Log security event to database"""
        conn = sqlite3.connect('/tmp/security_monitor.db', check_same_thread=False)
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO security_events 
            (timestamp, event_type, severity, container_name, source_ip, description, threat_score)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', (
            datetime.utcnow().isoformat(),
            event_type,
            severity,
            container,
            source_ip,
            description,
            threat_score
        ))
        
        conn.commit()
        conn.close()
        
        # Add to in-memory alerts for real-time display
        alert = {
            "timestamp": datetime.utcnow().isoformat(),
            "type": event_type,
            "severity": severity,
            "container": container,
            "source_ip": source_ip,
            "description": description,
            "threat_score": threat_score
        }
        
        self.alerts.append(alert)
        if len(self.alerts) > 100:  # Keep only last 100 alerts
            self.alerts.pop(0)
        
        self.threat_score += threat_score
    
    def simulate_security_events(self):
        """Simulate various security events for demonstration"""
        while True:
            # Generate random security events
            event_types = [
                ("normal_activity", "INFO", 0),
                ("failed_login", "WARNING", 2),
                ("privilege_escalation", "CRITICAL", 10),
                ("unusual_network", "WARNING", 3),
                ("malware_detected", "CRITICAL", 15),
                ("unauthorized_access", "HIGH", 7),
                ("ddos_attempt", "HIGH", 8),
                ("data_exfiltration", "CRITICAL", 12)
            ]
            
            event_type, severity, score = random.choice(event_types)
            container = random.choice(self.containers) if random.random() > 0.3 else None
            source_ip = f"192.168.1.{random.randint(1, 254)}"
            
            descriptions = {
                "normal_activity": "Container health check passed",
                "failed_login": f"Failed login attempt from {source_ip}",
                "privilege_escalation": f"Privilege escalation attempt detected in {container}",
                "unusual_network": f"Unusual network activity detected in {container}",
                "malware_detected": f"Malware signature detected in {container}",
                "unauthorized_access": f"Unauthorized file access in {container}",
                "ddos_attempt": f"DDoS attack attempt from {source_ip}",
                "data_exfiltration": f"Suspicious data transfer from {container}"
            }
            
            self.log_security_event(
                event_type,
                severity,
                container,
                source_ip,
                descriptions[event_type],
                score
            )
            
            # Update metrics
            self.metrics[f"{severity}_events"] += 1
            self.metrics["total_events"] += 1
            
            # Random interval between events
            time.sleep(random.uniform(5, 30))
    
    def start_monitoring(self):
        """Start background monitoring thread"""
        monitor_thread = threading.Thread(target=self.simulate_security_events, daemon=True)
        monitor_thread.start()
    
    def get_threat_level(self):
        """Calculate current threat level"""
        if self.threat_score > 50:
            return "CRITICAL"
        elif self.threat_score > 25:
            return "HIGH" 
        elif self.threat_score > 10:
            return "MEDIUM"
        else:
            return "LOW"
    
    def get_recent_alerts(self, limit=20):
        """Get recent security alerts"""
        return self.alerts[-limit:]
    
    def get_security_metrics(self):
        """Get security metrics summary"""
        return dict(self.metrics)

# Initialize security monitor
security_monitor = SecurityMonitor()

@app.route('/')
def dashboard():
    """Security monitoring dashboard"""
    dashboard_html = '''
    <!DOCTYPE html>
    <html>
    <head>
        <title>Security Monitoring Dashboard</title>
        <meta http-equiv="refresh" content="10">
        <style>
            body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
            .header { background: #2c3e50; color: white; padding: 20px; margin: -20px -20px 20px -20px; }
            .metrics { display: flex; gap: 20px; margin-bottom: 20px; }
            .metric-card { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); flex: 1; }
            .metric-value { font-size: 2em; font-weight: bold; color: #3498db; }
            .metric-label { color: #7f8c8d; }
            .alerts { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
            .alert { padding: 10px; margin: 5px 0; border-left: 4px solid; border-radius: 4px; }
            .alert.CRITICAL { border-color: #e74c3c; background: #fadbd8; }
            .alert.HIGH { border-color: #f39c12; background: #fdeaa7; }
            .alert.WARNING { border-color: #f1c40f; background: #fcf3cf; }
            .alert.INFO { border-color: #3498db; background: #d6eaf8; }
            .threat-level { font-size: 1.5em; padding: 10px; border-radius: 5px; text-align: center; margin: 10px 0; }
            .threat-CRITICAL { background: #e74c3c; color: white; }
            .threat-HIGH { background: #f39c12; color: white; }
            .threat-MEDIUM { background: #f1c40f; color: black; }
            .threat-LOW { background: #27ae60; color: white; }
        </style>
    </head>
    <body>
        <div class="header">
            <h1>🛡️ Enterprise Security Monitoring Dashboard</h1>
            <p>Real-time container security monitoring and threat detection</p>
        </div>
        
        <div class="metrics">
            <div class="metric-card">
                <div class="metric-value">{{ metrics.total_events or 0 }}</div>
                <div class="metric-label">Total Events</div>
            </div>
            <div class="metric-card">
                <div class="metric-value">{{ metrics.CRITICAL_events or 0 }}</div>
                <div class="metric-label">Critical Alerts</div>
            </div>
            <div class="metric-card">
                <div class="metric-value">{{ threat_score }}</div>
                <div class="metric-label">Threat Score</div>
            </div>
            <div class="metric-card">
                <div class="threat-level threat-{{ threat_level }}">{{ threat_level }}</div>
            </div>
        </div>
        
        <div class="alerts">
            <h2>Recent Security Alerts</h2>
            {% for alert in alerts %}
            <div class="alert {{ alert.severity }}">
                <strong>[{{ alert.timestamp[:19] }}]</strong> 
                <span style="background: #{{ alert.severity == 'CRITICAL' and 'e74c3c' or alert.severity == 'HIGH' and 'f39c12' or alert.severity == 'WARNING' and 'f1c40f' or '3498db' }}; color: white; padding: 2px 6px; border-radius: 3px; font-size: 0.8em;">{{ alert.severity }}</span>
                {{ alert.description }}
                {% if alert.container %} | Container: {{ alert.container }}{% endif %}
                {% if alert.source_ip %} | Source: {{ alert.source_ip }}{% endif %}
            </div>
            {% endfor %}
        </div>
        
        <div style="margin-top: 20px; padding: 10px; background: #ecf0f1; border-radius: 5px;">
            <small>Last updated: {{ current_time }} | Auto-refresh every 10 seconds</small>
        </div>
    </body>
    </html>
    '''
    
    return render_template_string(
        dashboard_html,
        alerts=security_monitor.get_recent_alerts(),
        metrics=security_monitor.get_security_metrics(),
        threat_score=security_monitor.threat_score,
        threat_level=security_monitor.get_threat_level(),
        current_time=datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')
    )

@app.route('/api/alerts')
def get_alerts():
    """API endpoint for alerts"""
    return jsonify({
        "alerts": security_monitor.get_recent_alerts(),
        "threat_level": security_monitor.get_threat_level(),
        "threat_score": security_monitor.threat_score
    })

@app.route('/api/metrics')
def get_metrics():
    """API endpoint for metrics"""
    return jsonify(security_monitor.get_security_metrics())

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5002, debug=True)
```

### Task 4.2: Automated Incident Response System

```bash
#!/bin/bash
# incident_response.sh

set -euo pipefail

# Configuration
ALERT_THRESHOLD_CRITICAL=10
ALERT_THRESHOLD_HIGH=5
LOG_FILE="/tmp/incident_response.log"
NOTIFICATION_WEBHOOK="${NOTIFICATION_WEBHOOK:-}"

# Logging function
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Incident response actions
isolate_container() {
    local container_name=$1
    log_message "ISOLATING CONTAINER: $container_name"
    
    # Disconnect from networks (except default)
    networks=$(docker inspect "$container_name" --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' 2>/dev/null || echo "")
    for network in $networks; do
        if [[ "$network" != "bridge" ]]; then
            docker network disconnect "$network" "$container_name" 2>/dev/null || true
            log_message "Disconnected $container_name from network $network"
        fi
    done
    
    # Pause container
    docker pause "$container_name" 2>/dev/null || true
    log_message "Container $container_name paused"
}

collect_forensic_data() {
    local container_name=$1
    local incident_id=$2
    local forensics_dir="/tmp/forensics_${incident_id}"
    
    log_message "COLLECTING FORENSIC DATA for $container_name"
    mkdir -p "$forensics_dir"
    
    # Container logs
    docker logs "$container_name" > "$forensics_dir/container_logs.txt" 2>&1 || true
    
    # Process list
    docker exec "$container_name" ps aux > "$forensics_dir/processes.txt" 2>/dev/null || true
    
    # Network connections
    docker exec "$container_name" netstat -tuln > "$forensics_dir/network_connections.txt" 2>/dev/null || true
    
    # File system changes
    docker diff "$container_name" > "$forensics_dir/filesystem_changes.txt" 2>/dev/null || true
    
    # Container configuration
    docker inspect "$container_name" > "$forensics_dir/container_config.json" 2>/dev/null || true
    
    # Create forensic image
    docker commit "$container_name" "forensic-evidence:${incident_id}" 2>/dev/null || true
    
    log_message "Forensic data collected in $forensics_dir"
}

deploy_replacement_container() {
    local original_container=$1
    local backup_image=$2
    
    log_message "DEPLOYING REPLACEMENT CONTAINER for $original_container"
    
    # Get original container configuration
    local original_config=$(docker inspect "$original_container" 2>/dev/null || echo "[]")
    local networks=$(echo "$original_config" | jq -r '.[0].NetworkSettings.Networks | keys[]' 2>/dev/null || echo "")
    local ports=$(echo "$original_config" | jq -r '.[0].NetworkSettings.Ports | keys[]' 2>/dev/null || echo "")
    
    # Stop original container
    docker stop "$original_container" 2>/dev/null || true
    
    # Deploy replacement
    local replacement_name="${original_container}-recovery"
    docker run -d \
        --name "$replacement_name" \
        --restart unless-stopped \
        --read-only \
        --cap-drop=ALL \
        --security-opt=no-new-privileges:true \
        "$backup_image" 2>/dev/null || true
    
    # Reconnect to networks
    for network in $networks; do
        if [[ "$network" != "bridge" ]]; then
            docker network connect "$network" "$replacement_name" 2>/dev/null || true
        fi
    done
    
    log_message "Replacement container $replacement_name deployed"
}

send_notification() {
    local incident_type=$1
    local container_name=$2
    local details=$3
    
    local message="🚨 SECURITY INCIDENT: $incident_type
Container: $container_name
Details: $details
Time: $(date)
Host: $(hostname)
Action: Automated response initiated"
    
    log_message "SENDING NOTIFICATION: $incident_type for $container_name"
    
    # Send to webhook if configured
    if [[ -n "$NOTIFICATION_WEBHOOK" ]]; then
        curl -X POST "$NOTIFICATION_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{\"text\":\"$message\"}" 2>/dev/null || true
    fi
    
    # Log notification
    echo "$message" >> "/tmp/security_notifications.log"
}

# Incident response handler
handle_incident() {
    local incident_type=$1
    local container_name=$2
    local severity=$3
    local details=$4
    
    local incident_id="INC-$(date +%Y%m%d%H%M%S)-$(echo $container_name | tr '[:lower:]' '[:upper:]')"
    
    log_message "INCIDENT DETECTED: $incident_id - $incident_type ($severity)"
    log_message "Container: $container_name"
    log_message "Details: $details"
    
    # Send immediate notification
    send_notification "$incident_type" "$container_name" "$details"
    
    case "$severity" in
        "CRITICAL")
            log_message "CRITICAL INCIDENT - Initiating full response"
            
            # Immediate isolation
            isolate_container "$container_name"
            
            # Collect forensic evidence
            collect_forensic_data "$container_name" "$incident_id"
            
            # Deploy replacement if backup image available
            if docker images | grep -q "${container_name}-backup"; then
                deploy_replacement_container "$container_name" "${container_name}-backup:latest"
            fi
            
            # Alert security team
            send_notification "CRITICAL SECURITY ALERT" "$container_name" "Container isolated and forensic data collected. Incident ID: $incident_id"
            ;;
            
        "HIGH")
            log_message "HIGH SEVERITY - Enhanced monitoring and isolation"
            
            # Isolate but don't pause
            networks=$(docker inspect "$container_name" --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' 2>/dev/null || echo "")
            for network in $networks; do
                if [[ "$network" != "bridge" ]]; then
                    docker network disconnect "$network" "$container_name" 2>/dev/null || true
                fi
            done
            
            # Collect logs
            collect_forensic_data "$container_name" "$incident_id"
            ;;
            
        "MEDIUM"|"WARNING")
            log_message "MEDIUM SEVERITY - Enhanced monitoring"
            
            # Increase logging verbosity
            docker logs --tail 100 "$container_name" > "/tmp/enhanced_monitoring_${incident_id}.log" 2>&1 || true
            
            # Monitor for escalation
            echo "$incident_id:$container_name:$(date +%s)" >> "/tmp/incident_watch_list.txt"
            ;;
            
        *)
            log_message "UNKNOWN SEVERITY - Standard logging"
            ;;
    esac
    
    log_message "Incident response completed for $incident_id"
}

# Test the incident response system
test_incident_response() {
    echo "🧪 Testing Incident Response System"
    
    # Simulate various incidents
    handle_incident "privilege_escalation" "web-app-test" "CRITICAL" "Sudo command executed by non-privileged user"
    handle_incident "malware_detected" "api-service-test" "CRITICAL" "Malicious binary detected in /tmp"
    handle_incident "unusual_network" "cache-test" "HIGH" "Unexpected outbound connections to unknown hosts"
    handle_incident "failed_authentication" "db-test" "WARNING" "Multiple failed login attempts"
    
    echo "✅ Incident response test completed"
    echo "Check logs at: $LOG_FILE"
}

# Main execution
if [[ "${1:-}" == "test" ]]; then
    test_incident_response
elif [[ $# -eq 4 ]]; then
    handle_incident "$1" "$2" "$3" "$4"
else
    echo "Usage: $0 <incident_type> <container_name> <severity> <details>"
    echo "   or: $0 test"
    echo ""
    echo "Example: $0 privilege_escalation web-app-1 CRITICAL 'Root shell spawned'"
    exit 1
fi
```

**Deliverables**:
- [ ] Real-time security monitoring dashboard
- [ ] Automated incident response system
- [ ] Forensic data collection capabilities
- [ ] Notification and alerting system

---

## 🎯 Module 5 Challenge: Complete Enterprise Security Implementation

**Master Challenge**: Create a complete enterprise-grade secure application deployment with all security controls, compliance measures, and monitoring systems.

### Requirements:
1. **Secure Multi-Tier Application**:
   - Web frontend with security headers
   - API backend with authentication
   - Database with encrypted connections
   - Redis cache with access controls

2. **Security Hardening**:
   - Distroless or minimal base images
   - Non-root users throughout
   - Read-only filesystems
   - Capability dropping
   - Resource limits

3. **Secrets Management**:
   - Docker Swarm secrets for sensitive data
   - Proper secret rotation procedures
   - No hardcoded credentials

4. **Compliance Implementation**:
   - GDPR data processing logging
   - PCI-DSS security controls
   - SOC 2 audit trails

5. **Monitoring and Response**:
   - Real-time security monitoring
   - Automated threat detection
   - Incident response automation
   - Forensic data collection

6. **CI/CD Security**:
   - Automated vulnerability scanning
   - Security gate controls
   - Image signing and verification
   - Compliance validation

### Success Criteria:
- [ ] Zero critical vulnerabilities in final images
- [ ] All containers running as non-root
- [ ] Complete audit trail for all data processing
- [ ] Automated response to security incidents
- [ ] Compliance with at least two frameworks
- [ ] Sub-10 second incident detection and response
- [ ] Complete forensic data collection capability

**Estimated Time**: 4-6 hours

---

## 📚 Additional Resources

### Security Tools
- **Trivy**: Comprehensive vulnerability scanner
- **Docker Scout**: Built-in Docker security scanning
- **Falco**: Runtime security monitoring
- **Anchore**: Container security platform
- **Twistlock/Prisma Cloud**: Enterprise container security

### Compliance Frameworks
- **NIST Cybersecurity Framework**: Comprehensive security guidelines
- **CIS Controls**: Critical security controls
- **ISO 27001**: Information security management
- **OWASP Container Security**: Web application security

### Best Practices
- **NIST SP 800-190**: Container security guidelines
- **CIS Docker Benchmark**: Docker security configuration
- **OWASP Docker Security**: Container security cheat sheet
- **Docker Security Documentation**: Official security guides

This module provides comprehensive coverage of enterprise container security, ensuring you can implement, monitor, and maintain secure containerized environments that meet enterprise compliance requirements.