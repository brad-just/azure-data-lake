# Docker — Context

@../CLAUDE.md

---

## Custom Spark image

The only custom image in this project is the Spark image at `docker/spark/Dockerfile`. All other services use upstream Helm chart images.

### Why a custom image is needed

The Bitnami Spark base image does not include the JARs required for Iceberg, Nessie catalog integration, or ADLS Gen2 access. These must be bundled at build time.

### Required JARs

The Dockerfile must download and copy the following JARs into `$SPARK_HOME/jars/`:

- `iceberg-spark-runtime-<spark-version>_<scala-version>-<iceberg-version>.jar`
- `nessie-spark-extensions-<spark-version>_<scala-version>-<nessie-version>.jar`
- `hadoop-azure-<version>.jar`
- `azure-storage-<version>.jar` (hadoop-azure dependency)

Leave `# TODO: pin exact versions` comments on each JAR — versions must be aligned with the Spark version used in the Bitnami Helm chart. Check the chart's `appVersion` before pinning.

### Dockerfile pattern

```dockerfile
FROM bitnami/spark:<version>  # TODO: match version in helm/spark-values.yaml

USER root

RUN curl -fSL <jar-url> -o $SPARK_HOME/jars/<jar-name>.jar
# ... repeat for each JAR

USER 1001  # revert to non-root bitnami default
```

Download JARs from Maven Central (`https://repo1.maven.org/maven2/`) — do not use unofficial mirrors.

### Build and push

Handled by `.github/workflows/spark-image.yml`. The image is pushed to ACR and tagged with `github.sha`. See `.github/CLAUDE.md` for the tag propagation pattern.

### Local build (for testing)

```bash
docker build -t spark-local:dev docker/spark/
```

No local push needed — ACR is the only registry used in this project.