import requests
import os
# URL pública del Load Balancer o localhost
#API_URL = "http://api-load-balancer-1889023243.us-east-1.elb.amazonaws.com"  # Cambia al DNS del Load Balancer en AWS si es necesario
API_URL = os.getenv("API_URL")

# 1. Endpoint: `/`
def test_home():
    response = requests.get(f"{API_URL}/")
    assert response.status_code == 200
    print("✔️ /home responde correctamente")

# 2. Endpoint: `/shortest-path`
def test_shortest_path():
    params = {"origen": "final", "destino": "found"}
    response = requests.get(f"{API_URL}/shortest-path", params=params)
    if response.status_code == 404:
        print("✔️ /shortest-path: Nodos no existen en el grafo (esperado)")
    else:
        assert response.status_code == 200
        print("✔️ /shortest-path responde correctamente")

# 3. Endpoint: `/all-paths`
# def test_all_paths():
#     params = {"origen": "did", "destino": "dispose"}
#     response = requests.get(f"{API_URL}/all-paths", params=params)
#     if response.status_code == 404:
#         print("✔️ /all-paths: Nodos no existen en el grafo (esperado)")
#     else:
#         assert response.status_code == 200
#         print("✔️ /all-paths responde correctamente")
def test_all_paths():
    params = {
        "origen": "final",
        "destino": "found",
        "max_depth": 6,  # Limita la profundidad de los caminos (opcional)
        "max_paths": 20  # Limita el número de rutas a devolver (opcional)
    }
    response = requests.get(f"{API_URL}/all-paths", params=params)
    if response.status_code == 404:
        print("✔️ /all-paths: Nodos no existen en el grafo (esperado)")
    else:
        assert response.status_code == 200
        paths_data = response.json().get("weighted_paths", [])
        print(f"✔️ /all-paths responde correctamente con {len(paths_data)} caminos devueltos")

# 4. Endpoint: `/maximum-distance`
def test_maximum_distance():
    response = requests.get(f"{API_URL}/maximum-distance")
    assert response.status_code == 200
    print("✔️ /maximum-distance responde correctamente")

# 5. Endpoint: `/clusters`
def test_clusters():
    response = requests.get(f"{API_URL}/clusters")
    assert response.status_code == 200
    print("✔️ /clusters responde correctamente")

# 6. Endpoint: `/high-connectivity-nodes`
def test_high_connectivity_nodes():
    params = {"min": 2}
    response = requests.get(f"{API_URL}/high-connectivity-nodes", params=params)
    assert response.status_code == 200
    print("✔️ /high-connectivity-nodes responde correctamente")

# 7. Endpoint: `/nodes-by-degree`
def test_nodes_by_degree():
    params = {"degree": 2}
    response = requests.get(f"{API_URL}/nodes-by-degree", params=params)
    assert response.status_code == 200
    print("✔️ /nodes-by-degree responde correctamente")

# 8. Endpoint: `/isolated-nodes`
def test_isolated_nodes():
    response = requests.get(f"{API_URL}/isolated-nodes")
    assert response.status_code == 200
    print("✔️ /isolated-nodes responde correctamente")

# 9. Endpoint: `/filter-graph`
def test_filter_graph():
    params = {"min": 3, "max": 6}
    response = requests.get(f"{API_URL}/filter-graph", params=params)
    assert response.status_code == 200
    print("✔️ /filter-graph responde correctamente")

# 10. Endpoint: `/reset-graph`
def test_reset_graph():
    response = requests.get(f"{API_URL}/reset-graph")
    assert response.status_code == 200
    print("✔️ /reset-graph responde correctamente")

# 11. Endpoint: `/health`
def test_health():
    response = requests.get(f"{API_URL}/health")
    assert response.status_code == 200
    print("✔️ /health responde correctamente")

# Ejecutar todas las pruebas
if __name__ == "__main__":
    print("\n=== Ejecutando pruebas de API ===\n")
    test_home()
    test_shortest_path()
    test_all_paths()
    test_maximum_distance()
    test_clusters()
    test_high_connectivity_nodes()
    test_nodes_by_degree()
    test_isolated_nodes()
    test_filter_graph()
    test_reset_graph()
    test_health()
