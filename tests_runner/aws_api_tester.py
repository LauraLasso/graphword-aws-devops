import os
import subprocess
import time
import threading

# Environment variables
AWS_REGION = "us-east-1"
# API_URL = "http://api-load-balancer-1889023243.us-east-1.elb.amazonaws.com"
API_URL = os.getenv("API_URL")

# Function to run shell commands
def run_command(command, ignore_error=True):
    print(f"Executing: {command}")
    result = subprocess.run(command, shell=True)
    if result.returncode != 0:
        if not ignore_error:
            exit(1)

# Unit and Integration Tests
def run_unit_integration_tests():
    os.environ["AWS_REGION"] = AWS_REGION
    os.environ["API_URL"] = API_URL

    print("\n==== Running Unit and Integration Tests ====")
    run_command("pip install -r requeriments.txt")  # Install requirements
    run_command("pip install pytest requests boto3")  # Install additional libraries
    run_command("pytest tests/unit")  # Run unit tests
    run_command("pytest tests/integration")  # Run integration tests

# API Tests
def run_api_tests():
    print("\n==== Running API Tests ====")
    run_command("pip install requests boto3")  # Install necessary libraries
    run_command(f"python tests/api/test_endpoints.py --api-url={API_URL}")  # Execute API tests

# Performance Tests with Locust
def run_performance_tests():
    print("\n==== Running Performance Tests with Locust ====")
    run_command("pip install locust prometheus_client")  # Install Locust and Prometheus libraries

    # Run Locust and expose metrics for Prometheus
    run_command(
        f"locust --headless -u 50 -r 20 --run-time 5m "
        f"-H {API_URL} -f tests/performance/locustfile.py --web-port 9102"
    )

# Monitoring with Prometheus
def run_monitoring():
    print("\n==== Running Monitoring with Prometheus ====")
    run_command("pip install prometheus_client requests")  # Install Prometheus client

    # Wait 5 seconds to ensure Locust is running
    print("Waiting to ensure Locust is collecting metrics...")
    time.sleep(5)

    # Fetch metrics from Prometheus
    print("\n==== Fetching Metrics from Prometheus ====")
    run_command("curl -X GET \"http://localhost:9102/metrics\"")

# Function to execute performance tests and monitoring simultaneously
def run_performance_and_monitoring():
    # Create threads to execute functions in parallel
    monitoring_thread = threading.Thread(target=run_monitoring)
    performance_thread = threading.Thread(target=run_performance_tests)

    # Start threads
    monitoring_thread.start()
    performance_thread.start()

    # Wait for both threads to finish
    monitoring_thread.join()
    performance_thread.join()

# Security Tests with OWASP ZAP
def run_security_tests():
    print("\n==== Running Security Tests with OWASP ZAP ====")
    run_command("sudo apt-get update && sudo apt-get install -y zaproxy")  # Install ZAP
    run_command(f"zap-cli start")  # Start ZAP CLI
    run_command(f"zap-cli open-url {API_URL}")  # Open the API URL in ZAP
    run_command(f"zap-cli active-scan {API_URL}")  # Perform active scan
    run_command(f"zap-cli report -o zap_report.html -f html")  # Generate scan report

# Main entry point
if __name__ == "__main__":
    # run_unit_integration_tests()  # Uncomment to run unit and integration tests
    run_api_tests()  # Run API tests
    print("Starting API, monitoring, and performance tests...")
    run_performance_and_monitoring()  # Run performance tests and monitoring simultaneously
    # run_performance_tests()  # Uncomment to run performance tests independently
    # run_monitoring()  # Uncomment to run monitoring independently
    # run_security_tests()  # Uncomment to run security tests
