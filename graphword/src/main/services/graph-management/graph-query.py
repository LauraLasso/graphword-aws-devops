import os
import json
import time
import networkx as nx
import matplotlib.pyplot as plt
import io
from flask import Flask, jsonify, request, Response

app = Flask(__name__)

graph = nx.DiGraph()


def log_event(endpoint, params, status_code, processing_time=None, additional_data=None):

    if endpoint == "/health":
        return
    current_date = time.strftime('%Y%m%d')
    daily_folder = os.path.join('datalake', 'events', current_date)
    os.makedirs(daily_folder, exist_ok=True) 

    daily_log_file = os.path.join(daily_folder, 'events.json')

    if not os.path.exists(daily_log_file):
        with open(daily_log_file, 'w') as f:
            json.dump([], f)

    event = {
        "timestamp": time.strftime('%Y-%m-%d %H:%M:%S'),
        "endpoint": endpoint,
        "url": request.url,
        "method": request.method,
        "params": params,
        "status_code": status_code,
        "processing_time": processing_time,
        "ip_address": request.remote_addr,
        "user_agent": request.headers.get('User-Agent'),
        "additional_data": additional_data or {}
    }

    try:
        with open(daily_log_file, 'r+') as f:
            logs = json.load(f)  
            logs.append(event)  
            f.seek(0)  
            json.dump(logs, f, indent=4)  
            f.truncate()  
    except json.JSONDecodeError:
        with open(daily_log_file, 'w') as f:
            json.dump([event], f, indent=4)
            

@app.before_request
def log_request():
    if request.method == 'GET':
        endpoint = request.path

        if endpoint == "/health":
            return

        params = request.args.to_dict()
        log_event(endpoint, params, None)  

import glob

def cargar_grafo_desde_txt():
    global graph, original_graph
    base_path = 'datamart_graph'
    original_file = os.path.join(base_path, 'word_graph.txt')
    script_directory = os.path.dirname(os.path.abspath(__file__))

    filtered_graph_files = glob.glob(os.path.join(script_directory, "filtered_graph_*.txt"))

    if filtered_graph_files:
        filtered_graph_file = sorted(filtered_graph_files)[-1]
        file_path = filtered_graph_file
        print(f"Filtered graph file found: {file_path}")
    else:
        file_path = original_file
        print(f"No filtered graphs found. Using original file: {file_path}")

    os.makedirs(base_path, exist_ok=True)

    if not os.path.exists(file_path):
        print(f"File {file_path} not found. Creating an empty file...")
        open(file_path, 'w').close() 
        return 

    graph = nx.DiGraph()
    with open(file_path, 'r', encoding='utf-8') as f:
        for line in f:
            parts = line.strip().split()
            if len(parts) == 3:
                palabra1, palabra2, peso = parts
                graph.add_edge(palabra1, palabra2, weight=float(peso))

    original_graph = graph.copy()  
    print(f"Graph loaded from: {file_path}")


cargar_grafo_desde_txt()

@app.route('/')
def home():
    routes = [
        {"path": "/shortest-path?origen=<node>&destino=<node>", "description": "Find the shortest path between two nodes."},
        {"path": "/all-paths?origen=<node>&destino=<node>&max_depth=<number>&max_paths=<number>", "description": "Find possible paths between two nodes with optional limits on maximum length and number of paths."},
        {"path": "/maximum-distance", "description": "Calculate the maximum distance between nodes."},
        {"path": "/clusters", "description": "Display the graph's clusters."},
        {"path": "/high-connectivity-nodes?min=<number>", "description": "List nodes with high connectivity."},
        {"path": "/nodes-by-degree?degree=<number>", "description": "List nodes with a specific degree."},
        {"path": "/isolated-nodes", "description": "List isolated nodes in the graph."},
        {"path": "/health", "description": "Check if the API is running correctly."},
        {"path": "/filter-graph?min=<length>&max=<length>", "description": "Filter the graph by word length and display the filtered nodes and edges."},
        {"path": "/reset-graph", "description": "Reset the graph to its original state."}
    ]

    html = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <title>API - Available Routes</title>
        <style>
            body {
                font-family: Arial, sans-serif;
                margin: 20px;
                padding: 20px;
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
        <h1>Welcome to the Graph API</h1>
        <p>Select one of the following routes:</p>
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


@app.route('/shortest-path', methods=['GET'])
def shortest_path():
    start_time = time.time()
    origen = request.args.get('origen')
    destino = request.args.get('destino')
    params = {"origen": origen, "destino": destino}

    if not (graph.has_node(origen) and graph.has_node(destino)):
        processing_time = time.time() - start_time
        log_event('/shortest-path', params, 404, processing_time, {"error": "One or both nodes do not exist"})
        return jsonify({'error': 'One or both nodes do not exist'}), 404

    try:
        path = nx.shortest_path(graph, source=origen, target=destino, weight='weight')
        total_weight = sum(graph[path[i]][path[i + 1]]['weight'] for i in range(len(path) - 1))
        processing_time = time.time() - start_time
        log_event('/shortest-path', params, 200, processing_time, {"path": path, "total_weight": total_weight})
        return jsonify({'path': path, 'total_weight': total_weight}), 200
    except nx.NetworkXNoPath:
        processing_time = time.time() - start_time
        log_event('/shortest-path', params, 404, processing_time, {"error": "No path exists between the nodes"})
        return jsonify({'error': 'No path exists between the nodes'}), 404


@app.route('/all-paths', methods=['GET'])
def all_paths():
    start_time = time.time()
    origen = request.args.get('origen')
    destino = request.args.get('destino')
    max_depth = int(request.args.get('max_depth', 5))  
    max_paths = int(request.args.get('max_paths', 50)) 
    params = {"origen": origen, "destino": destino}

    if not (graph.has_node(origen) and graph.has_node(destino)):
        processing_time = time.time() - start_time
        log_event('/all-paths', params, 404, processing_time, {"error": "One or both nodes do not exist"})
        return jsonify({'error': 'One or both nodes do not exist'}), 404

    try:
        paths = []
        for path in nx.all_simple_paths(graph, source=origen, target=destino, cutoff=max_depth):
            if len(paths) >= max_paths:
                break
            weighted_path = {
                'path': path,
                'total_weight': sum(graph[path[i]][path[i + 1]]['weight'] for i in range(len(path) - 1))
            }
            paths.append(weighted_path)

        processing_time = time.time() - start_time
        log_event('/all-paths', params, 200, processing_time, {"weighted_paths": paths})
        return jsonify({'weighted_paths': paths}), 200
    except Exception as e:
        processing_time = time.time() - start_time
        log_event('/all-paths', params, 500, processing_time, {"error": str(e)})
        return jsonify({'error': 'Internal server error'}), 500


@app.route('/maximum-distance', methods=['GET'])
def maximum_distance():
    start_time = time.time()
    try:
        all_distances = dict(nx.all_pairs_shortest_path_length(graph))
        max_distance = max(max(distances.values()) for distances in all_distances.values())
        processing_time = time.time() - start_time
        log_event('/maximum-distance', {}, 200, processing_time, {"maximum_distance": max_distance})
        return jsonify({'maximum_distance': max_distance}), 200
    except Exception as e:
        processing_time = time.time() - start_time
        log_event('/maximum-distance', {}, 500, processing_time, {"error": str(e)})
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/health', methods=['GET'])
def health():
    return "OK", 200

@app.route('/filter-graph', methods=['GET'])  
def filter_graph():
    global graph  

    longitud_min = int(request.args.get('min', 1))  
    longitud_max = int(request.args.get('max', 10)) 

    subgraph = nx.DiGraph()

    for u, v, d in graph.edges(data=True):
        if longitud_min <= len(u) <= longitud_max and longitud_min <= len(v) <= longitud_max:
            subgraph.add_edge(u, v, **d)

    graph = subgraph

    script_directory = os.path.dirname(os.path.abspath(__file__))

    filtered_graph_file = os.path.join(script_directory, f"filtered_graph_{longitud_min}_{longitud_max}.txt")
    
    with open(filtered_graph_file, 'w', encoding='utf-8') as f:
        for u, v, d in subgraph.edges(data=True):
            weight = d.get('weight', 1.0)  
            f.write(f"{u} {v} {weight}\n")

    return jsonify({
        "status": "success",
        "message": f"Filtered graph saved as {filtered_graph_file} with words of length between {longitud_min} and {longitud_max}",
        "nodes_count": len(graph.nodes),
        "edges_count": len(graph.edges),
        "file_path": filtered_graph_file
    })

@app.route('/reset-graph', methods=['GET'])
def reset_graph():
    global graph, original_graph
    script_directory = os.path.dirname(os.path.abspath(__file__))

    for filename in os.listdir(script_directory):
        if filename.startswith("filtered_graph_") and filename.endswith(".txt"):
            file_path = os.path.join(script_directory, filename)
            try:
                os.remove(file_path)
                print(f"File deleted: {file_path}")
            except Exception as e:
                print(f"Error deleting file {file_path}: {e}")

    cargar_grafo_desde_txt()
    return jsonify({"status": "success", "message": "Graph reset to original state and filtered graph files deleted."})

@app.route('/clusters', methods=['GET'])
def clusters():
    start_time = time.time()
    try:
        cluster_list = list(nx.weakly_connected_components(graph))
        clusters = [list(cluster) for cluster in cluster_list]
        processing_time = time.time() - start_time
        log_event('/clusters', {}, 200, processing_time, {"clusters_count": len(clusters)})
        return jsonify({'clusters': clusters, 'total_clusters': len(clusters)}), 200
    except Exception as e:
        processing_time = time.time() - start_time
        log_event('/clusters', {}, 500, processing_time, {"error": str(e)})
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/high-connectivity-nodes', methods=['GET'])
def high_connectivity_nodes():
    start_time = time.time()
    min_connections = int(request.args.get('min', 1)) 
    params = {"min_connections": min_connections}
    try:
        high_connectivity = [node for node, degree in graph.degree() if degree >= min_connections]
        processing_time = time.time() - start_time
        log_event('/high-connectivity-nodes', params, 200, processing_time, {"nodes_count": len(high_connectivity)})
        return jsonify({'high_connectivity_nodes': high_connectivity}), 200
    except Exception as e:
        processing_time = time.time() - start_time
        log_event('/high-connectivity-nodes', params, 500, processing_time, {"error": str(e)})
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/nodes-by-degree', methods=['GET'])
def nodes_by_degree():
    start_time = time.time()
    degree = int(request.args.get('degree'))
    params = {"degree": degree}
    try:
        nodes = [node for node, deg in graph.degree() if deg == degree]
        processing_time = time.time() - start_time
        log_event('/nodes-by-degree', params, 200, processing_time, {"nodes_count": len(nodes)})
        return jsonify({'nodes': nodes}), 200
    except Exception as e:
        processing_time = time.time() - start_time
        log_event('/nodes-by-degree', params, 500, processing_time, {"error": str(e)})
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/isolated-nodes', methods=['GET'])
def isolated_nodes():
    start_time = time.time()
    try:
        isolated = [node for node in graph.nodes() if graph.degree(node) == 0]
        processing_time = time.time() - start_time
        log_event('/isolated-nodes', {}, 200, processing_time, {"isolated_nodes_count": len(isolated)})
        return jsonify({'isolated_nodes': isolated}), 200
    except Exception as e:
        processing_time = time.time() - start_time
        log_event('/isolated-nodes', {}, 500, processing_time, {"error": str(e)})
        return jsonify({'error': 'Internal server error'}), 500


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)