import os
import json
from flask import Flask, jsonify

app = Flask(__name__)

STATS_FILE = os.path.join("datamart_stats", "statistics.json")

def load_statistics():
    if not os.path.exists(STATS_FILE):
        return {"error": "Statistics not found. Please run stat-builder.py first."}
    with open(STATS_FILE, 'r', encoding='utf-8') as f:
        return json.load(f)

@app.route('/', methods=['GET'])
def home():
    routes = [
        {"path": "/stats", "description": "Displays all available statistics."},
        {"path": "/stats/processing-times", "description": "Average processing times per endpoint."},
        {"path": "/stats/requests-by-ip", "description": "Number of requests made from each IP address."},
        {"path": "/stats/user-agents", "description": "Summary of user agents used."},
        {"path": "/stats/errors", "description": "Error statistics by endpoint."},
    ]

    html = """
    <!DOCTYPE html>
    <html lang="es">
    <head>
        <meta charset="UTF-8">
        <title>API - Statistics</title>
        <style>
            body {
                font-family: Arial, sans-serif;
                margin: 20px;
                background-color: #f9f9f9;
            }
            h1 {
                color: #333;
            }
            ul {
                list-style-type: none;
                padding: 0;
            }
            li {
                margin: 10px 0;
            }
            a {
                text-decoration: none;
                color: #1a73e8;
                font-size: 18px;
            }
            a:hover {
                text-decoration: underline;
            }
            .description {
                font-size: 14px;
                color: #666;
            }
        </style>
    </head>
    <body>
        <h1>Welcome to the Statistics API</h1>
        <p>Select one of the following routes to explore:</p>
        <ul>
    """

    for route in routes:
        html += f"""
        <li>
            <a href="{route['path']}">{route['path']}</a>
            <div class="description">{route['description']}</div>
        </li>
        """

    html += """
        </ul>
    </body>
    </html>
    """
    return html

@app.route('/stats', methods=['GET'])
def get_all_statistics():
    stats = load_statistics()
    return jsonify(stats)

@app.route('/stats/processing-times', methods=['GET'])
def get_processing_times():
    stats = load_statistics()
    return jsonify(stats.get("average_processing_time_by_endpoint", {}))

@app.route('/stats/requests-by-ip', methods=['GET'])
def get_requests_by_ip():
    stats = load_statistics()
    return jsonify(stats.get("requests_by_ip", {}))

@app.route('/stats/user-agents', methods=['GET'])
def get_user_agents():
    stats = load_statistics()
    return jsonify(stats.get("user_agents", {}))

@app.route('/stats/errors', methods=['GET'])
def get_error_statistics():
    stats = load_statistics()
    return jsonify(stats.get("error_requests", {}))

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080, debug=True)
