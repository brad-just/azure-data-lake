# Helm — Context

@../CLAUDE.md

---

## General rules

- One values file per service under `helm/`
- All Helm installs use `--atomic --cleanup-on-fail --timeout 5m` (Airbyte uses `--timeout 10m`)
- Chart versions are pinned in `helm/chart-versions.yaml` — never let `helm repo update` silently upgrade a chart. To upgrade: bump the version in that file and open a PR.
- Secrets are never in values files — they come from Kubernetes secrets created by External Secrets Operator from Azure Key Vault
- Reference the ESO-provisioned secret name in values using `existingSecret` or equivalent chart parameter

---

## Service-specific notes

### Nessie (`nessie-values.yaml`)
- Chart: `projectnessie/nessie`
- Backend: `JDBC` using PostgreSQL (`nessie_db`)
- Expose via ClusterIP only — internal access from Spark and Trino only
- Key Vault secret needed: postgres connection string for `nessie_db`

### Airbyte (`airbyte-values.yaml`)
- Chart: `airbyte/airbyte`
- Disable bundled PostgreSQL — point at external `airbyte_db`
- Configure Azure Blob Storage for logs: container `airbyte-logs`
- Key Vault secrets needed: postgres credentials, blob storage connection string

### Spark (`spark-values.yaml`)
- Chart: `spark-operator/spark-operator` (`helm repo add spark-operator https://kubeflow.github.io/spark-operator`)
- Installs the operator controller only — no persistent master/worker cluster
- Airflow submits jobs via `SparkKubernetesOperator` which creates `SparkApplication` CRDs at runtime
- The Spark driver and executor pods use a dedicated service account annotated for AKS workload identity
- Executor pods run on the Spark node pool (`agentpool: spark`, taint `dedicated=spark:NoSchedule`)
- Image reference (`${ACR_LOGIN_SERVER}/spark:${SPARK_IMAGE_TAG}`) lives in the SparkApplication CRD submitted by Airflow, not in these values
- Leave TODO comments for: executor memory, executor cores, concurrent reconciler workers

### Trino (`trino-values.yaml`)
- Chart: `trinodb/trino`
- Configure an Iceberg catalog:
  ```yaml
  additionalCatalogs:
    iceberg: |
      connector.name=iceberg
      iceberg.catalog.type=rest
      iceberg.rest-catalog.uri=http://nessie.nessie.svc.cluster.local/api/v1
      hive.azure.adl-oauth2-credential-provider=...
      # TODO: complete ADLS Gen2 workload identity auth config
  ```
- Expose coordinator via ClusterIP; add basic ingress with a TODO for TLS

### Superset (`superset-values.yaml`)
- Chart: `superset/superset`
- External PostgreSQL: `superset_db`
- **Use the Redis instance bundled with this chart** — do not set `redis.enabled: false`
- Key Vault secrets needed: postgres credentials, Superset secret key

### Airflow (`airflow-values.yaml`)
- Chart: `apache-airflow/airflow`
- Executor: `KubernetesExecutor`
- External PostgreSQL: `airflow_db`
- DAGs: add a placeholder ConfigMap mount with a single no-op DAG; leave a TODO for git-sync wiring
- Key Vault secrets needed: postgres credentials, Fernet key

---

## External Secrets Operator pattern

Secrets flow: **Azure Key Vault → ESO → Kubernetes Secret**

A single `ClusterSecretStore` (`helm/eso-cluster-secret-store.yaml`) points at the Key Vault using the AKS kubelet managed identity. Per-service `ExternalSecret` resources (`helm/<service>-external-secret.yaml`) pull the required secrets and create persistent Kubernetes Secrets in each namespace.

Unlike the Secrets Store CSI Driver, ESO secrets are persistent — they are not deleted when pods stop. This means no bootstrap pod is needed before Helm deploys.

ESO is deployed to its own `external-secrets` namespace before any service. The deploy workflow:
1. Installs ESO via Helm (`external-secrets/external-secrets`, version pinned in `chart-versions.yaml`)
2. Applies `eso-cluster-secret-store.yaml` (substitutes Key Vault name, tenant, and identity via `envsubst`)
3. For each service: applies `<service>-external-secret.yaml`, waits for `condition=Ready=True`, then runs `helm upgrade --install`

Example `ExternalSecret`:

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: <service>-secrets
  namespace: <service>
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: azure-keyvault
  target:
    name: <service>-secrets
    creationPolicy: Owner
  data:
    - secretKey: <k8s-secret-key>
      remoteRef:
        key: <keyvault-secret-name>
```