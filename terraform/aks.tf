resource "azurerm_kubernetes_cluster" "main" {
  name                = "${var.project}-aks"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  dns_prefix          = "${var.project}-aks"
  kubernetes_version  = var.aks_kubernetes_version

  # Public cluster — API server is reachable from the internet but restricted
  # to the CIDRs below. Do not set private_cluster_enabled = true.
  api_server_access_profile {
    authorized_ip_ranges = var.api_server_authorized_ip_ranges
  }

  default_node_pool {
    name                        = "system"
    node_count                  = var.aks_system_node_count
    vm_size                     = var.aks_system_vm_size
    vnet_subnet_id              = azurerm_subnet.aks.id
    os_disk_type                = "Managed"
    temporary_name_for_rotation = "systmp"

    upgrade_settings {
      max_surge = "10%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
    # service_cidr must not overlap the VNet address space (10.0.0.0/16)
    service_cidr   = "10.240.0.0/16"
    dns_service_ip = "10.240.0.10"
  }

  workload_identity_enabled = true
  oidc_issuer_enabled       = true

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  tags = local.tags
}

# Separate node pool for Spark workloads — memory-optimised, autoscaling,
# tainted so only Spark pods are scheduled here.
resource "azurerm_kubernetes_cluster_node_pool" "spark" {
  name                  = "spark"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.aks_spark_vm_size
  vnet_subnet_id        = azurerm_subnet.aks.id
  os_disk_type          = "Managed"

  auto_scaling_enabled = true
  min_count            = var.aks_spark_min_count
  max_count            = var.aks_spark_max_count

  node_taints = ["dedicated=spark:NoSchedule"]
  node_labels = {
    agentpool = "spark"
  }

  tags = local.tags
}
