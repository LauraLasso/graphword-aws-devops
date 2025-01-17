from prometheus_client import start_http_server, Summary
import requests
import time

# Definir una métrica de Prometheus (por ejemplo, tiempo de respuesta)
REQUEST_TIME = Summary('request_processing_seconds', 'Tiempo de respuesta de las solicitudes')

# Decorador para medir el tiempo de respuesta
@REQUEST_TIME.time()
def check_health(api_url):
    try:
        response = requests.get(f"{api_url}/health")
        if response.status_code == 200:
            print("API OK")
        else:
            print(f"Error: {response.status_code}")
    except Exception as e:
        print(f"Error al consultar la API: {e}")

if __name__ == "__main__":
    # Exponer las métricas en el puerto 8000 (por defecto)
    start_http_server(8000)
    API_URL = "http://my-api-deploy-url.amazonaws.com"
    while True:
        check_health(API_URL)
        time.sleep(10)  # Cada 10 segundos
