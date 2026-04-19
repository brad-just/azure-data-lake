FROM bitnami/spark:4.0.0

USER root

# Download JARs from Maven Central into the Spark jars directory so they are
# available to all Spark executors without any extra --jars configuration.
#
# Version alignment rules:
#   - iceberg-spark-runtime  → must match Spark major.minor (3.5) and Scala (2.12)
#   - nessie-spark-extensions → must match Spark major.minor and Nessie server version in nessie-values.yaml
#   - hadoop-azure            → must match the Hadoop version bundled in the Spark image
#                               (`hadoop version` inside the container to check)
#   - azure-storage           → dependency of hadoop-azure; check hadoop-azure POM for exact version

# TODO: pin exact versions after verifying against `helm show chart bitnami/spark` appVersion
# TODO: verify ICEBERG_VERSION at https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-4.0_2.13/
# TODO: verify NESSIE_VERSION at https://repo1.maven.org/maven2/org/projectnessie/nessie-integrations/nessie-spark-extensions-4.0_2.13/
# TODO: verify HADOOP_VERSION matches bundled Hadoop in bitnami/spark:4.0.0 — run `hadoop version` inside the container once the image is available
# TODO: verify AZURE_STORAGE_VERSION is compatible with hadoop-azure — check hadoop-azure POM on Maven Central
ARG ICEBERG_VERSION=1.7.1
ARG NESSIE_VERSION=0.99.0
ARG HADOOP_VERSION=3.4.0
ARG AZURE_STORAGE_VERSION=8.6.6

ARG SPARK_SCALA=4.0_2.13
ARG MAVEN=https://repo1.maven.org/maven2

RUN curl -fSL \
    "${MAVEN}/org/apache/iceberg/iceberg-spark-runtime-${SPARK_SCALA}/${ICEBERG_VERSION}/iceberg-spark-runtime-${SPARK_SCALA}-${ICEBERG_VERSION}.jar" \
    -o "${SPARK_HOME}/jars/iceberg-spark-runtime-${SPARK_SCALA}-${ICEBERG_VERSION}.jar" \
  && curl -fSL \
    "${MAVEN}/org/projectnessie/nessie-integrations/nessie-spark-extensions-${SPARK_SCALA}/${NESSIE_VERSION}/nessie-spark-extensions-${SPARK_SCALA}-${NESSIE_VERSION}.jar" \
    -o "${SPARK_HOME}/jars/nessie-spark-extensions-${SPARK_SCALA}-${NESSIE_VERSION}.jar" \
  && curl -fSL \
    "${MAVEN}/org/apache/hadoop/hadoop-azure/${HADOOP_VERSION}/hadoop-azure-${HADOOP_VERSION}.jar" \
    -o "${SPARK_HOME}/jars/hadoop-azure-${HADOOP_VERSION}.jar" \
  && curl -fSL \
    "${MAVEN}/com/microsoft/azure/azure-storage/${AZURE_STORAGE_VERSION}/azure-storage-${AZURE_STORAGE_VERSION}.jar" \
    -o "${SPARK_HOME}/jars/azure-storage-${AZURE_STORAGE_VERSION}.jar"

USER 1001
