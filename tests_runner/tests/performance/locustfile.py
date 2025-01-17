from locust import HttpUser, task, between

class PerformanceTest(HttpUser):
    wait_time = between(30, 40) 

    @task(1)
    def health_check(self):
        response = self.client.get("/health")
        if response.status_code == 200:
            print("Health check OK")
        else:
            print("Health check FAILED")

    @task(1)
    def shortest_path(self):
        response = self.client.get("/shortest-path?origen=final&destino=found")
        if response.status_code == 200:
            print("Shortest path OK")
        else:
            print("Shortest path FAILED")

    @task(1)
    def all_paths(self):
        response = self.client.get("/all-paths?origen=final&destino=found&max_depth=6&max_paths=20")
        if response.status_code == 200:
            paths_data = response.json().get("weighted_paths", [])
            print(f"✔️ All paths OK - Caminos devueltos: {len(paths_data)}")
        else:
            print(f"❌ All paths FAILED - Status code: {response.status_code}")

    @task(1)
    def maximum_distance(self):
        response = self.client.get("/maximum-distance")
        if response.status_code == 200:
            print("Maximum distance OK")
        else:
            print("Maximum distance FAILED")

    @task(1)
    def clusters(self):
        response = self.client.get("/clusters")
        if response.status_code == 200:
            print("Clusters OK")
        else:
            print("Clusters FAILED")

    @task(1)
    def high_connectivity_nodes(self):
        response = self.client.get("/high-connectivity-nodes?min=2")
        if response.status_code == 200:
            print("High connectivity nodes OK")
        else:
            print("High connectivity nodes FAILED")

    @task(1)
    def nodes_by_degree(self):
        response = self.client.get("/nodes-by-degree?degree=1")
        if response.status_code == 200:
            print("Nodes by degree OK")
        else:
            print("Nodes by degree FAILED")

    @task(1)
    def isolated_nodes(self):
        response = self.client.get("/isolated-nodes")
        if response.status_code == 200:
            print("Isolated nodes OK")
        else:
            print("Isolated nodes FAILED")

    @task(1)
    def filter_graph(self):
        response = self.client.get("/filter-graph?min=3&max=6")
        if response.status_code == 200:
            print("Filter graph OK")
        else:
            print("Filter graph FAILED")

    @task(1)
    def reset_graph(self):
        response = self.client.get("/reset-graph")
        if response.status_code == 200:
            print("Reset graph OK")
        else:
            print("Reset graph FAILED")
