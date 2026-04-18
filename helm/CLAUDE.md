# Helm — Context

@../CLAUDE.md

---

## General rules

- One values file per service under `helm/`
- All Helm installs use `--atomic --timeout 5m`
- Secrets are never in values files — they come from Kubernetes secrets provisioned by the Secrets Store CSI Driver from Key Vault
- Reference the CSI-provisioned secret name in values using `existingSecret` or equivalent chart parameter

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
- Chart: `bitnami/spark`
- **Do not use the default Bitnami image** — use the custom image from ACR
  - Image: `<acr-login-server>/spark:<tag>` — leave tag as a placeholder `# TODO: set to image tag output by spark-image.yml`
- Workers must be scheduled on the Spark node pool:
  ```yaml
  worker:
    nodeSelector:
      agentpool: spark
    tolerations:
      - key: dedicated
        operator: Equal
        value: spark
        effect: NoSchedule
  ```
- Leave TODO comments for: executor memory, executor cores, worker replicas

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

## Secrets Store CSI Driver pattern

For each service that needs a secret, produce a `SecretProviderClass` manifest alongside the values file. Example pattern:

```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: <service>-secrets
  namespace: <service>
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "true"
    userAssignedIdentityID: <aks-managed-identity-client-id>  # TODO: fill from Terraform output
    keyvaultName: <keyvault-name>                              # TODO: fill from Terraform output
    objects: |
      array:
        - |
          objectName: <secret-name-in-keyvault>
          objectType: secret
    tenantId: <tenant-id>                                      # TODO: fill from Terraform output
  secretObjects:
    - secretName: <k8s-secret-name>
      type: Opaque
      data:
        - objectName: <secret-name-in-keyvault>
          key: <key-in-k8s-secret>
```