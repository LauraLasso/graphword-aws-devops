import os
import json
import time
import networkx as nx
import matplotlib.pyplot as plt
import io
from flask import Flask, jsonify, request, Response

app = Flask(__name__)

# Inicializa el grafo
grafo = nx.DiGraph()

# Archivo para almacenar los eventos
# log_file_path = os.path.join('datalake', 'events.json')

# Asegurarse de que el archivo de registro existe
# os.makedirs(os.path.dirname(log_file_path), exist_ok=True)
# if not os.path.exists(log_file_path):
#     with open(log_file_path, 'w') as f:
#         json.dump([], f)

# Función para registrar eventos
def log_event(endpoint, params, status_code, processing_time=None, additional_data=None):
    # Obtener la fecha actual en formato YYYY-MM-DD
    current_date = time.strftime('%Y%m%d')

    # Determinar la carpeta para los eventos del día actual
    daily_folder = os.path.join('datalake', 'events', current_date)
    os.makedirs(daily_folder, exist_ok=True)  # Crear la carpeta si no existe

    # Ruta del archivo de eventos del día
    daily_log_file = os.path.join(daily_folder, 'events.json')

    # Crear el archivo si no existe
    if not os.path.exists(daily_log_file):
        with open(daily_log_file, 'w') as f:
            json.dump([], f)

    # Construir el evento
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

    # Leer el archivo actual, agregar el nuevo evento y escribir de vuelta
    try:
        with open(daily_log_file, 'r+') as f:
            logs = json.load(f)  # Leer eventos existentes
            logs.append(event)  # Agregar nuevo evento
            f.seek(0)  # Reposicionar el cursor al inicio del archivo
            json.dump(logs, f, indent=4)  # Escribir eventos actualizados
            f.truncate()  # Eliminar datos remanentes en caso de archivo más corto
    except json.JSONDecodeError:
        # Si el archivo está vacío o tiene un formato incorrecto, reiniciar con el evento actual
        with open(daily_log_file, 'w') as f:
            json.dump([event], f, indent=4)
            

# Middleware para registrar todas las solicitudes GET
@app.before_request
def log_request():
    if request.method == 'GET':
        endpoint = request.path
        params = request.args.to_dict()
        log_event(endpoint, params, None)  # Sin código de estado y sin tiempo de procesamiento aún

# Función para cargar el grafo desde un archivo .txt
def cargar_grafo_desde_txt():
    file_path = os.path.join('datamart_graph', 'word_graph.txt')  # Ajusta el nombre si es necesario
    if not os.path.exists(file_path):
        raise FileNotFoundError(f"Archivo no encontrado: {file_path}")

    with open(file_path, 'r', encoding='utf-8') as f:
        for line in f:
            parts = line.strip().split()
            if len(parts) == 3:
                palabra1, palabra2, peso = parts
                grafo.add_edge(palabra1, palabra2, weight=float(peso))

# Cargar el grafo al inicio
cargar_grafo_desde_txt()

@app.route('/')
def home():
    return "¡Hola mundo! \nVisita /grafo para ver el grafo."

@app.route('/grafo')
def dibujar_grafo():
    start_time = time.time()
    try:
        plt.figure()
        pos = nx.spring_layout(grafo)
        nx.draw(grafo, pos, with_labels=True, node_size=2000, node_color='skyblue', font_size=10, font_weight='bold', edge_color='gray')
        plt.title("Grafo de Palabras")

        img = io.BytesIO()
        plt.savefig(img, format='png')
        img.seek(0)
        plt.close()

        processing_time = time.time() - start_time
        log_event('/grafo', {}, 200, processing_time)
        return Response(img.getvalue(), mimetype='image/png')
    except Exception as e:
        processing_time = time.time() - start_time
        log_event('/grafo', {}, 500, processing_time, {"error": str(e)})
        return jsonify({'error': 'Error interno al generar el grafo'}), 500

@app.route('/shortest-path', methods=['GET'])
def shortest_path():
    start_time = time.time()
    origen = request.args.get('origen')
    destino = request.args.get('destino')
    params = {"origen": origen, "destino": destino}

    if not (grafo.has_node(origen) and grafo.has_node(destino)):
        processing_time = time.time() - start_time
        log_event('/shortest-path', params, 404, processing_time, {"error": "Uno o ambos nodos no existen"})
        return jsonify({'error': 'Uno o ambos nodos no existen'}), 404

    try:
        path = nx.shortest_path(grafo, source=origen, target=destino, weight='weight')
        total_weight = sum(grafo[path[i]][path[i + 1]]['weight'] for i in range(len(path) - 1))
        processing_time = time.time() - start_time
        log_event('/shortest-path', params, 200, processing_time, {"path": path, "total_weight": total_weight})
        return jsonify({'path': path, 'total_weight': total_weight}), 200
    except nx.NetworkXNoPath:
        processing_time = time.time() - start_time
        log_event('/shortest-path', params, 404, processing_time, {"error": "No hay camino entre los nodos"})
        return jsonify({'error': 'No hay camino entre los nodos'}), 404

@app.route('/all-paths', methods=['GET'])
def all_paths():
    start_time = time.time()
    origen = request.args.get('origen')
    destino = request.args.get('destino')
    params = {"origen": origen, "destino": destino}

    if not (grafo.has_node(origen) and grafo.has_node(destino)):
        processing_time = time.time() - start_time
        log_event('/all-paths', params, 404, processing_time, {"error": "Uno o ambos nodos no existen"})
        return jsonify({'error': 'Uno o ambos nodos no existen'}), 404

    try:
        paths = list(nx.all_simple_paths(grafo, source=origen, target=destino))
        weighted_paths = [
            {
                'path': path,
                'total_weight': sum(grafo[path[i]][path[i + 1]]['weight'] for i in range(len(path) - 1))
            }
            for path in paths
        ]
        processing_time = time.time() - start_time
        log_event('/all-paths', params, 200, processing_time, {"weighted_paths": weighted_paths})
        return jsonify({'weighted_paths': weighted_paths}), 200
    except Exception as e:
        processing_time = time.time() - start_time
        log_event('/all-paths', params, 500, processing_time, {"error": str(e)})
        return jsonify({'error': 'Error interno del servidor'}), 500

@app.route('/maximum-distance', methods=['GET'])
def maximum_distance():
    start_time = time.time()
    try:
        all_distances = dict(nx.all_pairs_shortest_path_length(grafo))
        max_distance = max(max(distances.values()) for distances in all_distances.values())
        processing_time = time.time() - start_time
        log_event('/maximum-distance', {}, 200, processing_time, {"maximum_distance": max_distance})
        return jsonify({'maximum_distance': max_distance}), 200
    except Exception as e:
        processing_time = time.time() - start_time
        log_event('/maximum-distance', {}, 500, processing_time, {"error": str(e)})
        return jsonify({'error': 'Error interno del servidor'}), 500

@app.route('/clusters', methods=['GET'])
def clusters():
    start_time = time.time()
    try:
        # Para grafos dirigidos, usamos weakly_connected_components
        cluster_list = list(nx.weakly_connected_components(grafo))
        clusters = [list(cluster) for cluster in cluster_list]
        processing_time = time.time() - start_time
        log_event('/clusters', {}, 200, processing_time, {"clusters_count": len(clusters)})
        return jsonify({'clusters': clusters, 'total_clusters': len(clusters)}), 200
    except Exception as e:
        processing_time = time.time() - start_time
        log_event('/clusters', {}, 500, processing_time, {"error": str(e)})
        return jsonify({'error': 'Error interno del servidor'}), 500

@app.route('/high-connectivity-nodes', methods=['GET'])
def high_connectivity_nodes():
    start_time = time.time()
    min_connections = int(request.args.get('min', 1))
    params = {"min_connections": min_connections}
    try:
        high_connectivity = [node for node, degree in grafo.degree() if degree >= min_connections]
        processing_time = time.time() - start_time
        log_event('/high-connectivity-nodes', params, 200, processing_time, {"nodes_count": len(high_connectivity)})
        return jsonify({'high_connectivity_nodes': high_connectivity}), 200
    except Exception as e:
        processing_time = time.time() - start_time
        log_event('/high-connectivity-nodes', params, 500, processing_time, {"error": str(e)})
        return jsonify({'error': 'Error interno del servidor'}), 500

@app.route('/nodes-by-degree', methods=['GET'])
def nodes_by_degree():
    start_time = time.time()
    degree = int(request.args.get('degree'))
    params = {"degree": degree}
    try:
        nodes = [node for node, deg in grafo.degree() if deg == degree]
        processing_time = time.time() - start_time
        log_event('/nodes-by-degree', params, 200, processing_time, {"nodes_count": len(nodes)})
        return jsonify({'nodes': nodes}), 200
    except Exception as e:
        processing_time = time.time() - start_time
        log_event('/nodes-by-degree', params, 500, processing_time, {"error": str(e)})
        return jsonify({'error': 'Error interno del servidor'}), 500

@app.route('/isolated-nodes', methods=['GET'])
def isolated_nodes():
    start_time = time.time()
    try:
        isolated = [node for node in grafo.nodes() if grafo.degree(node) == 0]
        processing_time = time.time() - start_time
        log_event('/isolated-nodes', {}, 200, processing_time, {"isolated_nodes_count": len(isolated)})
        return jsonify({'isolated_nodes': isolated}), 200
    except Exception as e:
        processing_time = time.time() - start_time
        log_event('/isolated-nodes', {}, 500, processing_time, {"error": str(e)})
        return jsonify({'error': 'Error interno del servidor'}), 500


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=9000)