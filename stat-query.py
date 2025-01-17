import os
import json
from flask import Flask, jsonify

app = Flask(__name__)

STATS_FILE = os.path.join("datamart_stats", "statistics.json")

def load_statistics():
    if not os.path.exists(STATS_FILE):
        return {"error": "Estadísticas no encontradas. Por favor, ejecute stat-builder.py primero."}
    with open(STATS_FILE, 'r', encoding='utf-8') as f:
        return json.load(f)

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
    app.run(host="0.0.0.0", port=8081, debug=True)
