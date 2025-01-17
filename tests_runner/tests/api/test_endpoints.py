import requests
import os

API_URL = os.getenv("API_URL")

# 1. Endpoint: `/`
def test_home():
    response = requests.get(f"{API_URL}/")
    assert response.status_code == 200
    print("✔️ /home responds correctly")

# 2. Endpoint: `/shortest-path`
def test_shortest_path():
    params = {"origen": "final", "destino": "found"}
    response = requests.get(f"{API_URL}/shortest-path", params=params)
    if response.status_code == 404:
        print("✔️ /shortest-path: Nodes do not exist in the graph (expected)")
    else:
        assert response.status_code == 200
        print("✔️ /shortest-path responds correctly")

# 3. Endpoint: `/all-paths`
def test_all_paths():
    params = {
        "origen": "final",
        "destino": "found",
        "max_depth": 6,  # Maximum depth
        "max_paths": 20  # Maximum number of paths
    }
    response = requests.get(f"{API_URL}/all-paths", params=params)
    if response.status_code == 404:
        print("✔️ /all-paths: Nodes do not exist in the graph (expected)")
    else:
        assert response.status_code == 200
        paths_data = response.json().get("weighted_paths", [])
        print(f"✔️ /all-paths responds correctly with {len(paths_data)} paths returned")

# 4. Endpoint: `/maximum-distance`
def test_maximum_distance():
    response = requests.get(f"{API_URL}/maximum-distance")
    assert response.status_code == 200
    print("✔️ /maximum-distance responds correctly")

# 5. Endpoint: `/clusters`
def test_clusters():
    response = requests.get(f"{API_URL}/clusters")
    assert response.status_code == 200
    print("✔️ /clusters responds correctly")

# 6. Endpoint: `/high-connectivity-nodes`
def test_high_connectivity_nodes():
    params = {"min": 2}
    response = requests.get(f"{API_URL}/high-connectivity-nodes", params=params)
    assert response.status_code == 200
    print("✔️ /high-connectivity-nodes responds correctly")

# 7. Endpoint: `/nodes-by-degree`
def test_nodes_by_degree():
    params = {"degree": 2}
    response = requests.get(f"{API_URL}/nodes-by-degree", params=params)
    assert response.status_code == 200
    print("✔️ /nodes-by-degree responds correctly")

# 8. Endpoint: `/isolated-nodes`
def test_isolated_nodes():
    response = requests.get(f"{API_URL}/isolated-nodes")
    assert response.status_code == 200
    print("✔️ /isolated-nodes responds correctly")

# 9. Endpoint: `/filter-graph`
def test_filter_graph():
    params = {"min": 3, "max": 6}
    response = requests.get(f"{API_URL}/filter-graph", params=params)
    assert response.status_code == 200
    print("✔️ /filter-graph responds correctly")

# 10. Endpoint: `/reset-graph`
def test_reset_graph():
    response = requests.get(f"{API_URL}/reset-graph")
    assert response.status_code == 200
    print("✔️ /reset-graph responds correctly")

# 11. Endpoint: `/health`
def test_health():
    response = requests.get(f"{API_URL}/health")
    assert response.status_code == 200
    print("✔️ /health responds correctly")

# Execute all tests
if __name__ == "__main__":
    print("\n=== Running API tests ===\n")
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