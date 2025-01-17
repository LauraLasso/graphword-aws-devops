```mermaid
graph TD
    A[Push or PR to master] --> B[Checkout Code]
    B --> C[Configure AWS CLI Credentials]
    C --> D[Setup Terraform]
    D --> E[Terraform Init]
    E --> F[Terraform Plan]
    F --> G[Terraform Apply]
    G --> H[Run Tests]
    H --> I[Run Performance Tests]
    I --> J[Run Monitoring with Prometheus/Grafana]
    J --> K[Terraform Destroy]
    K --> L[Create Release]
    L --> M[Merge to Develop]
    M --> N[Re-Run Terraform in Develop]
    N --> O[Pipeline Completed]

    G -->|Error| X[Notify Error]
    H -->|Error| X