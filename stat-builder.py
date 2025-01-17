import os
import json
from collections import defaultdict
from statistics import mean, median

class StatBuilder:
    def __init__(self, datalake_directory="datalake/events", datamart_directory="datamart_stats"):
        self.datalake_directory = datalake_directory
        self.datamart_directory = datamart_directory

    def gather_statistics(self):
        stats = {
            "total_requests": 0,
            "requests_by_endpoint": defaultdict(int),
            "requests_by_method": defaultdict(int),
            "status_code_distribution": defaultdict(int),
            "processing_times": defaultdict(list),
            "requests_by_ip": defaultdict(int),
            "user_agents": defaultdict(int),
            "error_requests": defaultdict(int),
            "average_processing_time_by_endpoint": {},
        }

        # Recorremos todos los archivos, incluyendo subdirectorios
        for root, dirs, files in os.walk(self.datalake_directory):
            for event_file in files:
                file_path = os.path.join(root, event_file)

                # Procesar solo archivos JSON
                if not event_file.endswith(".json"):
                    continue

                with open(file_path, 'r', encoding='utf-8') as f:
                    try:
                        events = json.load(f)
                    except json.JSONDecodeError:
                        continue

                    for event in events:
                        stats["total_requests"] += 1
                        endpoint = event["endpoint"]
                        method = event["method"]
                        status_code = event.get("status_code", "unknown")
                        ip_address = event["ip_address"]
                        user_agent = event["user_agent"]
                        processing_time = event.get("processing_time")

                        # Validaciones
                        if endpoint:
                            stats["requests_by_endpoint"][endpoint] += 1
                        if method:
                            stats["requests_by_method"][method] += 1
                        if status_code != "unknown":
                            stats["status_code_distribution"][status_code] += 1
                        if processing_time is not None:
                            stats["processing_times"][endpoint].append(processing_time)
                        if ip_address:
                            stats["requests_by_ip"][ip_address] += 1
                        if user_agent:
                            stats["user_agents"][user_agent] += 1
                        if isinstance(status_code, int) and 400 <= status_code < 600:
                            stats["error_requests"][endpoint] += 1

        # Calcular estadísticas de tiempos de procesamiento
        for endpoint, times in stats["processing_times"].items():
            if times:
                stats["average_processing_time_by_endpoint"][endpoint] = {
                    "average": mean(times),
                    "median": median(times),
                    "max": max(times),
                    "min": min(times),
                }

        return stats


    def save_statistics(self, stats):
        os.makedirs(self.datamart_directory, exist_ok=True)
        stats_file = os.path.join(self.datamart_directory, "statistics.json")
        with open(stats_file, 'w', encoding='utf-8') as f:
            json.dump(stats, f, indent=4, ensure_ascii=False)
        print(f"Estadísticas guardadas en: {stats_file}")

    def run(self):
        stats = self.gather_statistics()
        self.save_statistics(stats)


if __name__ == "__main__":
    builder = StatBuilder()
    builder.run()
