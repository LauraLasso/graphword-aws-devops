import os
import json
from flask import Flask, jsonify, request

app = Flask(__name__)

STAT_FILE = os.path.join("datamart_stats", "statistics.json")

def load_statistics():
    if not os.path.exists(STAT_FILE):
        return {"error": "Statistics not found. Please run stat-builder.py first."}
    with open(STAT_FILE, 'r', encoding='utf-8') as f:
        return json.load(f)


@app.route('/stats', methods=['GET'])
def get_statistics():
    stats = load_statistics()
    return jsonify(stats)


@app.route('/stats/most-common-words', methods=['GET'])
def most_common_words():
    stats = load_statistics()
    if "word_count" not in stats:
        return jsonify({"error": "Word count not available in statistics."}), 400
    
    top_n = int(request.args.get("n", 10))
    most_common = stats["word_count"]
    sorted_words = sorted(most_common.items(), key=lambda x: x[1], reverse=True)[:top_n]
    return jsonify({"most_common_words": sorted_words})


@app.route('/stats/largest-file', methods=['GET'])
def largest_file():
    stats = load_statistics()
    if "largest_file" not in stats:
        return jsonify({"error": "Largest file information not available."}), 400
    return jsonify(stats["largest_file"])

# se supone que el puerto que debería ir es el 9001
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
