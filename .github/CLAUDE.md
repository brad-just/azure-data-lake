# GitHub Actions — Context

@../CLAUDE.md

---

## Auth pattern

All workflows authenticate to Azure using OIDC — no client secrets. Use the `azure/login` action with:

```yaml
- uses: azure/login@v2
  with:
    client-id: ${{ secrets.AZURE_CLIENT_ID }}
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

The service principal is provisioned by Terraform with a federated credential. These three secrets must be set manually in GitHub after the first `terraform apply`.

---

## Required GitHub secrets

| Secret | Set by | Notes |
|---|---|---|
| `AZURE_CLIENT_ID` | Manual (from Terraform output `github_actions_client_id`) | OIDC — not a password |
| `AZURE_TENANT_ID` | Manual | Azure AD tenant |
| `AZURE_SUBSCRIPTION_ID` | Manual | Azure subscription |
| `TF_BACKEND_RESOURCE_GROUP` | Manual | Resource group containing tfstate storage |
| `TF_BACKEND_STORAGE_ACCOUNT` | Manual | Storage account name for tfstate |
| `ACR_LOGIN_SERVER` | Manual (from Terraform output `acr_login_server`) | e.g. `mydatalake.azurecr.io` |
| `AKS_CLUSTER_NAME` | Manual (from Terraform output) | |
| `AKS_RESOURCE_GROUP` | Manual | |

---

## Workflows

### `terraform.yml`
Triggers: push to `main` affecting `terraform/**`, or `workflow_dispatch`

Jobs:
- `lint` — `terraform fmt -check` and `terraform validate`
- `plan` — `terraform plan -out=tfplan`, upload `tfplan` as artifact
- `apply` — downloads artifact, runs `terraform apply tfplan`
  - Runs only on the `production` GitHub environment (requires manual approval)
  - Use `environment: production` in the job to enforce protection rules

### `spark-image.yml`
Triggers: push to `main` affecting `docker/spark/**`, or `workflow_dispatch`

Jobs:
- `build-and-push`:
  - Login to ACR via `azure/acr-login@v1`
  - Build `docker/spark/Dockerfile`
  - Tag as `${{ secrets.ACR_LOGIN_SERVER }}/spark:${{ github.sha }}` and `:latest`
  - Push both tags

**Important:** after pushing, write the image tag (`github.sha`) to a file and commit it back to the repo, or expose it as a workflow output so `helm-deploy.yml` can consume it without hardcoding `:latest`.

### `helm-deploy.yml`
Triggers: push to `main` affecting `helm/**`, or `workflow_dispatch` with a `service` string input

Jobs:
- `deploy`:
  - Get AKS credentials: `azure/aks-set-context@v3`
  - If `service` input is set, deploy only that chart
  - Otherwise deploy all charts in dependency order: nessie → airbyte → spark → trino → airflow → superset
  - Each install: `helm upgrade --install <name> <repo>/<chart> -f helm/<name>-values.yaml --atomic --timeout 5m`
  - Spark install must substitute the real image tag — read from the committed tag file or a workflow input; never hardcode `:latest`

### `ci.yml`
Triggers: pull_request to `main`

Jobs:
- `terraform-lint` — `terraform fmt -check` + `terraform validate`
- `helm-lint` — `helm lint` for each values file
- `docker-lint` — `hadolint docker/spark/Dockerfile`

No deploys on PRs.

---

## Spark image tag propagation

The `spark-image.yml` workflow builds and pushes a new image tagged with `github.sha`. The Helm values file must reference this tag — not `:latest` — so deploys are deterministic.

Recommended approach: after pushing the image, `spark-image.yml` commits a file `docker/spark/.current-tag` containing the SHA to the repo. `helm-deploy.yml` reads this file and passes the tag as a `--set image.tag=<sha>` override when installing the Spark chart.

Leave a `# TODO:` in both workflows marking where this wiring goes if the agent implements it differently.

---

## Dev environment cost management

Add a `scripts/dev-stop.sh` and `scripts/dev-start.sh` pair (plus a `teardown.yml` workflow) to let the developer spin the dev environment down to near-zero cost and back up again without destroying Terraform state.

### `scripts/dev-stop.sh`
- Stop the AKS cluster: `az aks stop --name <cluster> --resource-group <rg>`
- Stop the PostgreSQL server: `az postgres flexible-server stop --name <server> --resource-group <rg>`
- Print a reminder that PostgreSQL auto-restarts after 7 days (Azure limitation)
- Read cluster/server names from env vars or accept as arguments — do not hardcode

### `scripts/dev-start.sh`
- Start AKS: `az aks start --name <cluster> --resource-group <rg>`
- Start PostgreSQL: `az postgres flexible-server start --name <server> --resource-group <rg>`
- Wait for both to be ready before exiting

### `teardown.yml` workflow
Trigger: `workflow_dispatch` only (never runs automatically)

Jobs:
- Authenticate via OIDC (same pattern as other workflows)
- Run `scripts/dev-stop.sh` using Terraform outputs for resource names
- Add a prominent warning in the workflow UI description that this stops but does not destroy infrastructure — run `terraform destroy` manually if you want full teardown

Note: `terraform destroy` is intentionally not automated. Destroying and re-applying takes ~20 minutes and risks state drift. Prefer stop/start for routine cost management.