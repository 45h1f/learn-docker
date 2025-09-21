# Flask Web Application for Docker Optimization Demo
from flask import Flask, jsonify, render_template_string
import os
import psutil
import datetime

app = Flask(__name__)

HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <title>Docker Optimization Demo</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; }
        .container { background: rgba(255,255,255,0.1); padding: 30px; border-radius: 15px; backdrop-filter: blur(10px); }
        .info-card { background: rgba(255,255,255,0.2); padding: 20px; margin: 15px 0; border-radius: 10px; }
        h1 { text-align: center; margin-bottom: 30px; }
        .metric { display: inline-block; margin: 10px; padding: 10px; background: rgba(255,255,255,0.3); border-radius: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🐳 Docker Image Optimization Demo</h1>
        <div class="info-card">
            <h3>System Information</h3>
            <div class="metric"><strong>Memory Usage:</strong> {{ memory_mb }} MB</div>
            <div class="metric"><strong>CPU Count:</strong> {{ cpu_count }}</div>
            <div class="metric"><strong>Python Version:</strong> {{ python_version }}</div>
            <div class="metric"><strong>Container ID:</strong> {{ hostname }}</div>
            <div class="metric"><strong>Timestamp:</strong> {{ timestamp }}</div>
        </div>
        <div class="info-card">
            <h3>Environment Variables</h3>
            <p><strong>Environment:</strong> {{ env }}</p>
            <p><strong>Debug Mode:</strong> {{ debug }}</p>
            <p><strong>Version:</strong> {{ version }}</p>
        </div>
        <div class="info-card">
            <h3>Image Optimization Tips</h3>
            <ul>
                <li>Use Alpine Linux for smaller base images</li>
                <li>Implement multi-stage builds</li>
                <li>Minimize the number of layers</li>
                <li>Use .dockerignore to exclude unnecessary files</li>
                <li>Run as non-root user for security</li>
            </ul>
        </div>
    </div>
</body>
</html>
"""

@app.route('/')
def home():
    return render_template_string(HTML_TEMPLATE,
        memory_mb=round(psutil.virtual_memory().used / 1024 / 1024, 2),
        cpu_count=psutil.cpu_count(),
        python_version=os.sys.version.split()[0],
        hostname=os.uname().nodename,
        timestamp=datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        env=os.getenv('ENVIRONMENT', 'development'),
        debug=os.getenv('DEBUG', 'false'),
        version=os.getenv('APP_VERSION', '1.0.0')
    )

@app.route('/health')
def health():
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.datetime.now().isoformat(),
        'memory_mb': round(psutil.virtual_memory().used / 1024 / 1024, 2),
        'version': os.getenv('APP_VERSION', '1.0.0')
    })

@app.route('/info')
def info():
    return jsonify({
        'python_version': os.sys.version,
        'flask_version': Flask.__version__,
        'hostname': os.uname().nodename,
        'environment': os.getenv('ENVIRONMENT', 'development'),
        'debug': os.getenv('DEBUG', 'false'),
        'memory_mb': round(psutil.virtual_memory().used / 1024 / 1024, 2),
        'cpu_count': psutil.cpu_count()
    })

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5000))
    debug = os.getenv('DEBUG', 'false').lower() == 'true'
    app.run(host='0.0.0.0', port=port, debug=debug)