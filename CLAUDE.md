# Data Lake — Project Context

## Current state
> Update this section manually as work progresses.
- [x] Terraform — Done
- [x] Helm values — Done
- [x] Spark Docker - Done
- [x] GitHub Actions workflows — Debugging workflows

---

## Stack

| Role | Technology |
|---|---|
| Ingestion | Airbyte |
| Table format | Apache Iceberg |
| Iceberg catalog | Project Nessie |
| Iceberg data storage | ADLS Gen2 |
| Service operational storage | Azure Blob Storage (GRS) |
| Transformations | Apache Spark (spark-operator, AKS) |
| Query engine | Trino |
| Visualization | Apache Superset |
| Orchestration | Apache Airflow |
| Database | Azure PostgreSQL Flexible Server (shared) |
| Cache/broker | Redis bundled with Superset Helm chart |
| Container platform | AKS |
| Container registry | Azure Container Registry (ACR) |

---

## Repository layout

```
.
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── networking.tf
│   ├── storage.tf
│   ├── database.tf
│   ├── aks.tf
│   ├── iam.tf
│   ├── acr.tf
│   └── keyvault.tf
├── helm/
│   ├── airbyte-values.yaml
│   ├── nessie-values.yaml
│   ├── spark-values.yaml
│   ├── trino-values.yaml
│   ├── superset-values.yaml
│   └── airflow-values.yaml
├── docker/
│   └── spark/
│       └── Dockerfile
├── .github/
│   └── workflows/
│       ├── terraform.yml
│       ├── spark-image.yml
│       ├── helm-deploy.yml
│       └── ci.yml
└── README.md
```

---

## Architectural decisions

**Shared PostgreSQL Flexible Server, separate databases** — one instance with `airbyte_db`, `nessie_db`, `superset_db`, `airflow_db`. Do not split into separate instances unless load warrants it. All credentials stored in Azure Key Vault.

**No external Redis** — Superset uses the Redis instance bundled with its Helm chart. Do not provision Azure Cache for Redis.

**Spark via spark-operator** — Spark runs via the kubeflow spark-operator (chart: `spark-operator/spark-operator`). There is no persistent master/worker cluster; the operator spins up driver and executor pods per job on demand. Airflow submits jobs using `SparkKubernetesOperator` which creates `SparkApplication` CRDs. This avoids any dependency on Bitnami images (which moved to a paid registry in 2025).

**Custom Spark image** — the official `apache/spark` image does not include Iceberg, Nessie catalog, or hadoop-azure JARs. A custom image built from `apache/spark:3.5.3` is built via CI and pushed to ACR. The image tag is passed to Airflow's SparkApplication at runtime via the `SPARK_IMAGE_TAG` workflow variable.

**ADLS Gen2 for Iceberg, Blob Storage for operational data** — ADLS Gen2 (hierarchical namespace enabled) is used for all Iceberg table data. Azure Blob Storage (GRS) is used for Airbyte logs and state only.

**Workload identity for ADLS access** — Spark pods authenticate to ADLS Gen2 via AKS workload identity. No static storage credentials anywhere.

**OIDC for GitHub Actions** — the GitHub Actions service principal uses federated credentials, not client secrets. The repo name must be parameterized in Terraform.

---

## Helm deployment order

Always deploy in this order to respect catalog and database dependencies:

1. Nessie
2. Airbyte
3. Spark
4. Trino
5. Airflow
6. Superset

---

## Global conventions

- All secrets via Azure Key Vault → Secrets Store CSI Driver → Kubernetes secrets. Never hardcode credentials.
- Tag every Azure resource: `environment`, `project`, `managed-by = terraform`
- No hardcoded Azure region, subscription ID, or resource names — use Terraform variables/locals throughout
- Leave `# TODO:` comments where tuning is deferred (Spark executor memory, JAR version pinning, Airflow DAG location)
- Helm deploys use `--atomic --timeout 5m`