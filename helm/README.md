# Helm — Service Deployments

Helm values files and SecretProviderClass manifests for all data lake services
running on AKS. Secrets are never stored in these files — they are pulled from
Azure Key Vault at pod startup via the Secrets Store CSI Driver.

---

## Services

| Service | Chart | Namespace | Purpose |
|---|---|---|---|
| Nessie | `projectnessie/nessie` | `nessie` | Iceberg REST catalog (backed by PostgreSQL) |
| Airbyte | `airbyte/airbyte` | `airbyte` | Data ingestion |
| Spark | `bitnami/spark` | `spark` | Batch transformations (custom image from ACR) |
| Trino | `trinodb/trino` | `trino` | Interactive query over Iceberg tables |
| Airflow | `apache-airflow/airflow` | `airflow` | Orchestration (KubernetesExecutor) |
| Superset | `superset/superset` | `superset` | Visualisation |

**Deploy in this order** — each service depends on the ones above it:

```
Nessie → Airbyte → Spark → Trino → Airflow → Superset
```

---

## Prerequisites

- `kubectl` configured against the AKS cluster (`az aks get-credentials`)
- `helm` >= 3.x installed
- Secrets Store CSI Driver running on the cluster (installed via AKS add-on in Terraform)
- The following secrets added to Key Vault **before first deploy** (see below)

### Helm repos

Add all chart repositories once:

```bash
helm repo add projectnessie https://charts.projectnessie.org
helm repo add airbyte       https://airbytehq.github.io/helm-charts
helm repo add bitnami        https://charts.bitnami.com/bitnami
helm repo add trinodb        https://trinodb.github.io/charts
helm repo add apache-airflow https://airflow.apache.org
helm repo add superset       https://apache.github.io/superset
helm repo update
```

---

## Pre-deployment: add secrets to Key Vault

These secrets cannot be Terraform-generated and must be added manually before deploying:

```bash
KV=<your-keyvault-name>
BLOB_ACCOUNT=<your-blob-storage-account-name>
RG=<your-resource-group>

# Airbyte — blob storage connection string for logs and state
BLOB_KEY=$(az storage account keys list \
  --account-name $BLOB_ACCOUNT \
  --resource-group $RG \
  --query "[0].value" -o tsv)

az keyvault secret set --vault-name $KV \
  --name blob-connection-string \
  --value "DefaultEndpointsProtocol=https;AccountName=${BLOB_ACCOUNT};AccountKey=${BLOB_KEY};EndpointSuffix=core.windows.net"

# Superset secret key
az keyvault secret set --vault-name $KV \
  --name superset-secret-key \
  --value $(python3 -c "import secrets; print(secrets.token_hex(32))")

# Airflow Fernet key
az keyvault secret set --vault-name $KV \
  --name airflow-fernet-key \
  --value $(python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())")

# Nessie — full JDBC URL (avoids URL construction at runtime)
FQDN=$(cd terraform && terraform output -raw postgres_fqdn)

az keyvault secret set --vault-name $KV \
  --name nessie-jdbc-url \
  --value "jdbc:postgresql://${FQDN}/nessie_db?sslmode=require"
```

The postgres password and FQDN are already in Key Vault from `terraform apply`.

---

## Deploying

Each service has two files:
- `<service>-values.yaml` — Helm values
- `<service>-secret-provider.yaml` — SecretProviderClass manifest (where applicable)

Both file types contain `${VARIABLE}` placeholders that must be substituted at
deploy time via `envsubst`. Set all environment variables before running any
deploy command:

```bash
export AKS_KUBELET_IDENTITY_CLIENT_ID=$(az aks show \
  --name <cluster-name> --resource-group <rg> \
  --query identityProfile.kubeletidentity.clientId -o tsv)

export KEYVAULT_NAME=<your-keyvault-name>
export AZURE_TENANT_ID=$(az account show --query tenantId -o tsv)

# Terraform outputs
export POSTGRES_FQDN=$(cd terraform && terraform output -raw postgres_fqdn)
export ADLS_STORAGE_ACCOUNT_NAME=$(cd terraform && terraform output -raw adls_storage_account_name)
export BLOB_STORAGE_ACCOUNT_NAME=$(cd terraform && terraform output -raw blob_storage_account_name)

# From tfvars
export POSTGRES_ADMIN_USERNAME=<your-postgres-admin-username>

# Set by spark-image.yml after a Spark image build; read from committed tag file
export SPARK_IMAGE_TAG=$(cat docker/spark/.current-tag)
export ACR_LOGIN_SERVER=<your-acr-login-server>  # from `terraform output acr_login_server`
```

### Deploy all services (full stack)

```bash
# Nessie
kubectl create namespace nessie --dry-run=client -o yaml | kubectl apply -f -
envsubst < helm/nessie-secret-provider.yaml | kubectl apply -f -
helm upgrade --install nessie projectnessie/nessie \
  -f <(envsubst < helm/nessie-values.yaml) \
  --namespace nessie --atomic --timeout 5m

# Airbyte
kubectl create namespace airbyte --dry-run=client -o yaml | kubectl apply -f -
envsubst < helm/airbyte-secret-provider.yaml | kubectl apply -f -
helm upgrade --install airbyte airbyte/airbyte \
  -f <(envsubst < helm/airbyte-values.yaml) \
  --namespace airbyte --atomic --timeout 5m

# Spark
kubectl create namespace spark --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install spark bitnami/spark \
  -f <(envsubst < helm/spark-values.yaml) \
  --namespace spark --atomic --timeout 5m

# Trino
kubectl create namespace trino --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install trino trinodb/trino \
  -f <(envsubst < helm/trino-values.yaml) \
  --namespace trino --atomic --timeout 5m

# Airflow
kubectl create namespace airflow --dry-run=client -o yaml | kubectl apply -f -
envsubst < helm/airflow-secret-provider.yaml | kubectl apply -f -
helm upgrade --install airflow apache-airflow/airflow \
  -f <(envsubst < helm/airflow-values.yaml) \
  --namespace airflow --atomic --timeout 5m

# Superset
kubectl create namespace superset --dry-run=client -o yaml | kubectl apply -f -
envsubst < helm/superset-secret-provider.yaml | kubectl apply -f -
helm upgrade --install superset superset/superset \
  -f <(envsubst < helm/superset-values.yaml) \
  --namespace superset --atomic --timeout 5m
```

### Deploy a single service

```bash
SERVICE=nessie  # change as needed
kubectl create namespace $SERVICE --dry-run=client -o yaml | kubectl apply -f -
envsubst < helm/${SERVICE}-secret-provider.yaml | kubectl apply -f -
helm upgrade --install $SERVICE <repo>/$SERVICE \
  -f helm/${SERVICE}-values.yaml \
  --namespace $SERVICE --atomic --timeout 5m
```

CI/CD (`helm-deploy.yml`) handles this automatically — see `.github/CLAUDE.md`.

---

## Verifying deployments

```bash
# Check all pods are running
kubectl get pods -A

# Nessie API
kubectl port-forward svc/nessie 19120:19120 -n nessie
curl http://localhost:19120/api/v1/config

# Trino UI
kubectl port-forward svc/trino 8080:8080 -n trino
# Open http://localhost:8080

# Superset UI
kubectl port-forward svc/superset 8088:8088 -n superset
# Open http://localhost:8088

# Airflow UI
kubectl port-forward svc/airflow-webserver 8080:8080 -n airflow
# Open http://localhost:8080
```

---

## Secrets management

All secrets flow through Azure Key Vault → Secrets Store CSI Driver → Kubernetes secret:

```
Key Vault secret
      ↓
SecretProviderClass (helm/*-secret-provider.yaml)
      ↓
Kubernetes Secret (created when a pod mounts the CSI volume)
      ↓
Pod env var (via secretKeyRef in values.yaml)
```

Secrets are rotated automatically every 2 minutes (configured in the AKS add-on).
No credentials are stored in this repository or in Helm values.

---

## Values files: outstanding TODOs

Several values contain `# TODO` comments for items deferred until production:

| File | TODO |
|---|---|
| `spark-values.yaml` | Executor memory, worker replicas, workload identity annotation |
| `trino-values.yaml` | ADLS Gen2 auth config, ingress + TLS |
| `airbyte-values.yaml` | Workload identity for blob storage (currently uses connection string) |
| `airflow-values.yaml` | git-sync DAG delivery |
