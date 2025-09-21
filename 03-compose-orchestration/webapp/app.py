# Full-Stack Web Application with Docker Compose
from flask import Flask, render_template_string, jsonify, request
import psycopg2
import redis
import os
import json
import time
from datetime import datetime

app = Flask(__name__)

# Database configuration
DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'database'),
    'database': os.getenv('DB_NAME', 'webapp'),
    'user': os.getenv('DB_USER', 'admin'),
    'password': os.getenv('DB_PASSWORD', 'secret'),
    'port': os.getenv('DB_PORT', '5432')
}

# Redis configuration
REDIS_HOST = os.getenv('REDIS_HOST', 'cache')
REDIS_PORT = int(os.getenv('REDIS_PORT', '6379'))

# HTML Template
HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <title>Docker Compose Demo</title>
    <style>
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            margin: 0; 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            color: white;
        }
        .container { 
            max-width: 1200px; 
            margin: 0 auto; 
            padding: 20px; 
        }
        .header {
            text-align: center;
            padding: 40px 0;
        }
        .services {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin: 30px 0;
        }
        .service-card {
            background: rgba(255,255,255,0.1);
            padding: 20px;
            border-radius: 15px;
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255,255,255,0.2);
        }
        .status-badge {
            display: inline-block;
            padding: 5px 10px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: bold;
        }
        .status-healthy { background: #4caf50; }
        .status-error { background: #f44336; }
        .metrics {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin: 20px 0;
        }
        .metric {
            background: rgba(255,255,255,0.2);
            padding: 15px;
            border-radius: 10px;
            text-align: center;
        }
        .metric-value {
            font-size: 24px;
            font-weight: bold;
            color: #ffd700;
        }
        .logs {
            background: rgba(0,0,0,0.3);
            padding: 15px;
            border-radius: 10px;
            font-family: 'Courier New', monospace;
            font-size: 12px;
            max-height: 200px;
            overflow-y: auto;
        }
        button {
            background: #2196f3;
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 5px;
            cursor: pointer;
            margin: 5px;
        }
        button:hover { background: #1976d2; }
        .refresh { text-align: center; margin: 20px 0; }
    </style>
    <script>
        function refreshData() {
            location.reload();
        }
        
        function testDatabase() {
            fetch('/api/test-db')
                .then(response => response.json())
                .then(data => alert(JSON.stringify(data, null, 2)));
        }
        
        function testCache() {
            fetch('/api/test-cache')
                .then(response => response.json())
                .then(data => alert(JSON.stringify(data, null, 2)));
        }
        
        // Auto-refresh every 30 seconds
        setInterval(refreshData, 30000);
    </script>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🐳 Docker Compose Multi-Container Demo</h1>
            <p>Full-stack application with Flask, PostgreSQL, Redis, and Nginx</p>
        </div>
        
        <div class="services">
            <div class="service-card">
                <h3>🌐 Web Application</h3>
                <div class="status-badge status-healthy">RUNNING</div>
                <p><strong>Container:</strong> {{ hostname }}</p>
                <p><strong>Environment:</strong> {{ environment }}</p>
                <p><strong>Version:</strong> {{ version }}</p>
                <p><strong>Uptime:</strong> {{ uptime }} seconds</p>
            </div>
            
            <div class="service-card">
                <h3>🗄️ PostgreSQL Database</h3>
                <div class="status-badge {{ db_status_class }}">{{ db_status }}</div>
                <p><strong>Host:</strong> {{ db_host }}</p>
                <p><strong>Database:</strong> {{ db_name }}</p>
                <p><strong>Tables:</strong> {{ table_count }}</p>
                <button onclick="testDatabase()">Test Connection</button>
            </div>
            
            <div class="service-card">
                <h3>⚡ Redis Cache</h3>
                <div class="status-badge {{ redis_status_class }}">{{ redis_status }}</div>
                <p><strong>Host:</strong> {{ redis_host }}</p>
                <p><strong>Memory Usage:</strong> {{ redis_memory }}</p>
                <p><strong>Keys:</strong> {{ redis_keys }}</p>
                <button onclick="testCache()">Test Cache</button>
            </div>
        </div>
        
        <div class="metrics">
            <div class="metric">
                <div class="metric-value">{{ total_requests }}</div>
                <div>Total Requests</div>
            </div>
            <div class="metric">
                <div class="metric-value">{{ db_connections }}</div>
                <div>DB Connections</div>
            </div>
            <div class="metric">
                <div class="metric-value">{{ cache_hits }}</div>
                <div>Cache Hits</div>
            </div>
            <div class="metric">
                <div class="metric-value">{{ response_time }}ms</div>
                <div>Avg Response Time</div>
            </div>
        </div>
        
        <div class="service-card">
            <h3>📊 System Information</h3>
            <div class="logs">
{{ system_info }}
            </div>
        </div>
        
        <div class="refresh">
            <button onclick="refreshData()">🔄 Refresh Data</button>
            <p><small>Last updated: {{ timestamp }}</small></p>
        </div>
    </div>
</body>
</html>
"""

def get_db_connection():
    """Get database connection with retry logic"""
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        return conn
    except Exception as e:
        print(f"Database connection error: {e}")
        return None

def get_redis_connection():
    """Get Redis connection with retry logic"""
    try:
        r = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, decode_responses=True)
        r.ping()  # Test connection
        return r
    except Exception as e:
        print(f"Redis connection error: {e}")
        return None

def initialize_database():
    """Initialize database with sample tables"""
    conn = get_db_connection()
    if conn:
        try:
            cur = conn.cursor()
            
            # Create tables
            cur.execute("""
                CREATE TABLE IF NOT EXISTS requests (
                    id SERIAL PRIMARY KEY,
                    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    ip_address VARCHAR(45),
                    user_agent TEXT,
                    endpoint VARCHAR(255)
                )
            """)
            
            cur.execute("""
                CREATE TABLE IF NOT EXISTS metrics (
                    id SERIAL PRIMARY KEY,
                    metric_name VARCHAR(100),
                    metric_value INTEGER,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
            
            # Insert initial metrics
            cur.execute("INSERT INTO metrics (metric_name, metric_value) VALUES ('total_requests', 0) ON CONFLICT DO NOTHING")
            cur.execute("INSERT INTO metrics (metric_name, metric_value) VALUES ('db_connections', 0) ON CONFLICT DO NOTHING")
            
            conn.commit()
            cur.close()
            conn.close()
            print("Database initialized successfully")
        except Exception as e:
            print(f"Database initialization error: {e}")

def log_request(endpoint):
    """Log request to database"""
    conn = get_db_connection()
    if conn:
        try:
            cur = conn.cursor()
            cur.execute(
                "INSERT INTO requests (ip_address, user_agent, endpoint) VALUES (%s, %s, %s)",
                (request.remote_addr if request else '127.0.0.1', 
                 request.headers.get('User-Agent', 'Unknown') if request else 'System',
                 endpoint)
            )
            
            # Update request counter
            cur.execute("UPDATE metrics SET metric_value = metric_value + 1 WHERE metric_name = 'total_requests'")
            
            conn.commit()
            cur.close()
            conn.close()
        except Exception as e:
            print(f"Request logging error: {e}")

def get_system_stats():
    """Get system statistics"""
    stats = {}
    
    # Database stats
    conn = get_db_connection()
    if conn:
        try:
            cur = conn.cursor()
            cur.execute("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public'")
            stats['table_count'] = cur.fetchone()[0]
            
            cur.execute("SELECT metric_value FROM metrics WHERE metric_name = 'total_requests'")
            result = cur.fetchone()
            stats['total_requests'] = result[0] if result else 0
            
            cur.execute("SELECT COUNT(*) FROM pg_stat_activity")
            stats['db_connections'] = cur.fetchone()[0]
            
            cur.close()
            conn.close()
            stats['db_status'] = 'CONNECTED'
            stats['db_status_class'] = 'status-healthy'
        except Exception as e:
            stats['db_status'] = 'ERROR'
            stats['db_status_class'] = 'status-error'
            stats['table_count'] = 0
            stats['total_requests'] = 0
            stats['db_connections'] = 0
    else:
        stats['db_status'] = 'DISCONNECTED'
        stats['db_status_class'] = 'status-error'
        stats['table_count'] = 0
        stats['total_requests'] = 0
        stats['db_connections'] = 0
    
    # Redis stats
    r = get_redis_connection()
    if r:
        try:
            info = r.info()
            stats['redis_status'] = 'CONNECTED'
            stats['redis_status_class'] = 'status-healthy'
            stats['redis_memory'] = f"{info.get('used_memory_human', 'N/A')}"
            stats['redis_keys'] = r.dbsize()
            
            # Get cache hits from Redis
            stats['cache_hits'] = int(r.get('cache_hits') or 0)
        except Exception as e:
            stats['redis_status'] = 'ERROR'
            stats['redis_status_class'] = 'status-error'
            stats['redis_memory'] = 'N/A'
            stats['redis_keys'] = 0
            stats['cache_hits'] = 0
    else:
        stats['redis_status'] = 'DISCONNECTED'
        stats['redis_status_class'] = 'status-error'
        stats['redis_memory'] = 'N/A'
        stats['redis_keys'] = 0
        stats['cache_hits'] = 0
    
    return stats

@app.route('/')
def home():
    start_time = time.time()
    log_request('/')
    
    # Increment cache hits
    r = get_redis_connection()
    if r:
        r.incr('cache_hits')
    
    stats = get_system_stats()
    
    system_info = f"""Environment Variables:
DB_HOST: {os.getenv('DB_HOST', 'database')}
DB_NAME: {os.getenv('DB_NAME', 'webapp')}
REDIS_HOST: {os.getenv('REDIS_HOST', 'cache')}
FLASK_ENV: {os.getenv('FLASK_ENV', 'development')}

Container Information:
Hostname: {os.uname().nodename}
Python Version: {os.sys.version.split()[0]}
Flask Version: {Flask.__version__}

Service Status:
Database: {stats['db_status']}
Redis: {stats['redis_status']}
"""
    
    response_time = round((time.time() - start_time) * 1000, 2)
    
    return render_template_string(HTML_TEMPLATE,
        hostname=os.uname().nodename,
        environment=os.getenv('FLASK_ENV', 'development'),
        version=os.getenv('APP_VERSION', '1.0.0'),
        uptime=int(time.time()),
        timestamp=datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        db_host=DB_CONFIG['host'],
        db_name=DB_CONFIG['database'],
        redis_host=REDIS_HOST,
        response_time=response_time,
        system_info=system_info,
        **stats
    )

@app.route('/health')
def health():
    log_request('/health')
    
    health_status = {
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'services': {}
    }
    
    # Check database
    conn = get_db_connection()
    if conn:
        health_status['services']['database'] = 'healthy'
        conn.close()
    else:
        health_status['services']['database'] = 'unhealthy'
        health_status['status'] = 'degraded'
    
    # Check Redis
    r = get_redis_connection()
    if r:
        health_status['services']['redis'] = 'healthy'
    else:
        health_status['services']['redis'] = 'unhealthy'
        health_status['status'] = 'degraded'
    
    return jsonify(health_status)

@app.route('/api/test-db')
def test_db():
    log_request('/api/test-db')
    
    conn = get_db_connection()
    if conn:
        try:
            cur = conn.cursor()
            cur.execute("SELECT version()")
            version = cur.fetchone()[0]
            cur.execute("SELECT COUNT(*) FROM requests")
            request_count = cur.fetchone()[0]
            cur.close()
            conn.close()
            
            return jsonify({
                'status': 'success',
                'database_version': version,
                'total_requests': request_count,
                'timestamp': datetime.now().isoformat()
            })
        except Exception as e:
            return jsonify({'status': 'error', 'message': str(e)})
    else:
        return jsonify({'status': 'error', 'message': 'Cannot connect to database'})

@app.route('/api/test-cache')
def test_cache():
    log_request('/api/test-cache')
    
    r = get_redis_connection()
    if r:
        try:
            test_key = f"test:{int(time.time())}"
            test_value = f"Hello from Redis at {datetime.now().isoformat()}"
            
            r.setex(test_key, 60, test_value)  # Expire in 60 seconds
            retrieved_value = r.get(test_key)
            
            info = r.info()
            
            return jsonify({
                'status': 'success',
                'test_key': test_key,
                'test_value': test_value,
                'retrieved_value': retrieved_value,
                'redis_version': info.get('redis_version'),
                'memory_usage': info.get('used_memory_human'),
                'total_keys': r.dbsize(),
                'timestamp': datetime.now().isoformat()
            })
        except Exception as e:
            return jsonify({'status': 'error', 'message': str(e)})
    else:
        return jsonify({'status': 'error', 'message': 'Cannot connect to Redis'})

@app.route('/api/stats')
def api_stats():
    log_request('/api/stats')
    return jsonify(get_system_stats())

if __name__ == '__main__':
    # Initialize database on startup
    time.sleep(2)  # Wait for database to be ready
    initialize_database()
    
    port = int(os.getenv('PORT', 5000))
    debug = os.getenv('FLASK_ENV') == 'development'
    
    app.run(host='0.0.0.0', port=port, debug=debug)