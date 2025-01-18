import os
import subprocess
import time
import threading

AWS_REGION = "us-east-1"
API_URL = os.getenv("API_URL")

def run_command(command, ignore_error=True):
    print(f"Executing: {command}")
    result = subprocess.run(command, shell=True)
    if result.returncode != 0:
        if not ignore_error:
            exit(1)

def run_unit_integration_tests():
    os.environ["AWS_REGION"] = AWS_REGION
    os.environ["API_URL"] = API_URL

    print("\n==== Running Unit and Integration Tests ====")
    run_command("pip install -r requeriments.txt")  
    run_command("pip install pytest requests boto3")  
    run_command("pytest tests/unit")  
    run_command("pytest tests/integration")  

def run_api_tests():
    print("\n==== Running API Tests ====")
    run_command("pip install requests boto3")  
    run_command(f"python tests/api/test_endpoints.py --api-url={API_URL}")  

def run_performance_tests():
    print("\n==== Running Performance Tests with Locust ====")
    run_command("pip install locust")  
    run_command(
        f"locust --headless -u 50 -r 20 --run-time 5m "
        f"-H {API_URL} -f tests/performance/locustfile.py --web-port 9102"
    )

def run_monitoring():
    print("\n==== Running Monitoring with Prometheus ====")
    run_command("pip install prometheus_client requests")  

    print("Waiting to ensure Locust is collecting metrics...")
    time.sleep(5)

    print("\n==== Fetching Metrics from Prometheus ====")
    run_command("curl -X GET \"http://localhost:9102/metrics\"")

def run_performance_and_monitoring():
    monitoring_thread = threading.Thread(target=run_monitoring)
    performance_thread = threading.Thread(target=run_performance_tests)

    monitoring_thread.start()
    performance_thread.start()

    monitoring_thread.join()
    performance_thread.join()

def run_security_tests():
    print("\n==== Running Security Tests with OWASP ZAP ====")
    run_command("sudo apt-get update && sudo apt-get install -y zaproxy") 
    run_command(f"zap-cli start")  
    run_command(f"zap-cli open-url {API_URL}")  
    run_command(f"zap-cli active-scan {API_URL}")  
    run_command(f"zap-cli report -o zap_report.html -f html")  

if __name__ == "__main__":
    run_api_tests() 
    print("Starting API, monitoring, and performance tests...")
    run_performance_and_monitoring()
