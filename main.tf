resource "azurerm_resource_group" "this" {
  location = var.rg_location
  name     = var.rg_name
}

resource "azurerm_user_assigned_identity" "this" {
  location            = azurerm_resource_group.this.location
  name                = "storage${random_pet.this.id}"
  resource_group_name = azurerm_resource_group.this.name
}

module "security_group" {
  depends_on              = [module.subnet]
  source                  = "./modules/azure-security"
  name                    = local.name
  environment             = local.environment
  resource_group_name     = azurerm_resource_group.this.name
  resource_group_location = azurerm_resource_group.this.location
  subnet_ids              = module.subnet.default_subnet_id
  inbound_rules = [
    {
      name                  = "ssh"
      priority              = 101
      access                = "Allow"
      protocol              = "Tcp"
      source_address_prefix = "10.20.0.0/32"
      #source_address_prefixes    = ["10.20.0.0/32","10.21.0.0/32"]
      source_port_range          = "*"
      destination_address_prefix = "0.0.0.0/0"
      destination_port_range     = "22"
      description                = "ssh allowed port"
    },
    {
      name                       = "https"
      priority                   = 102
      access                     = "Allow"
      protocol                   = "*"
      source_address_prefix      = "VirtualNetwork"
      source_port_range          = "80,443"
      destination_address_prefix = "0.0.0.0/0"
      destination_port_range     = "22"
      description                = "ssh allowed port"
    }
  ]
  enable_diagnostic          = true
  log_analytics_workspace_id = module.log-analytics.workspace_id
}

module "network" {
  source              = "./modules/azure-network"
  name                = var.vnet_name
  resource_group_name = azurerm_resource_group.this.name
  address_space       = "10.0.0.0/16"
  subnet_prefixes     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24", "10.0.4.0/24"]
  subnet_names        = ["database", "container", "registry", "openai"]
  vnet_location       = var.vnet_location

  // Associating Network Security Group to subnet1.
  nsg_ids = {
    subnet1 = azurerm_network_security_group.nsg1.id
  }

  // Enabling specific service endpoints on subnet1 and subnet2.
  subnet_service_endpoints = {
    container = ["Microsoft.Storage"]
    database = ["Microsoft.Sql", "Microsoft.Storage", "Microsoft.AzureActiveDirectory"]
    openai = ["Microsoft.CognitiveServices"]
  }

  // Configuring service delegation for subnet1 and subnet2.
  subnet_delegation = {
    subnet1 = [
      {
        name = "Microsoft.Web/serverFarms"
        service_delegation = {
          name    = "Microsoft.Web/serverFarms"
          actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
        }
      }
    ]
    subnet2 = [
      {
        name = "Microsoft.Sql/managedInstances"
        service_delegation = {
          name    = "Microsoft.Sql/managedInstances"
          actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
        }
      }
    ]
  }

  // Applying tags to the virtual network.
  tags = {
    project = var.project_name
    maintainer = var.maintainer
    source = "terraform"
  }

  // Enabling private link endpoint network policies on subnet2 and subnet3.
  private_link_endpoint_network_policies_enabled = {
    subnet2 = true
  }
  private_link_service_network_policies_enabled = {
    subnet3 = true
  }
}

module "postgresql" {
  source = "./modules/azure-postgresql"

  name           = "pgsqlservername"
  location       = "canadacentral"
  resource_group = "pgsql-dev-rg"

  databases = {
    pgsqlservername1 = { collation = "en_US.utf8" },
    pgsqlservername2 = { chartset = "utf8" },
    pgsqlservername3 = { chartset = "utf8", collation = "en_US.utf8" },
    pgsqlservername4 = {}
  }

  administrator_login    = "pgsqladmin"
  administrator_password = "pgSql1313"

  sku_name       = "GP_Standard_D4ds_v4"
  pgsql_version  = "13"
  storagesize_mb = 262144

  ip_rules       = []
  firewall_rules = []

  diagnostics = {
    destination   = ""
    eventhub_name = ""
    logs          = ["all"]
    metrics       = ["all"]
  }
  sa_create_log = true
  sa_subnet_ids = []

  tags = {
    project = var.project_name
    maintainer = var.maintainer
    source = "terraform"
  }

  providers = {
    azurerm                   = azurerm
    azurerm.dns_zone_provider = azurerm.dns_zone_provider
  }
}

module "storage" {
  source = "./modules/azure-storage"

  storage_account_account_replication_type = "LRS"
  storage_account_account_tier             = "Standard"
  storage_account_account_kind             = "StorageV2"
  storage_account_location                 = azurerm_resource_group.this.location
  storage_account_name                     = "tfmodstoracc${random_pet.this.id}"
  storage_account_resource_group_name      = azurerm_resource_group.this.name
  storage_account_min_tls_version          = "TLS1_2"
  storage_account_network_rules = {
    bypass         = ["AzureServices"]
    default_action = "Deny"
    ip_rules       = [local.public_ip]
  }
  storage_account_identity = {
    identity_ids = {
      msi = azurerm_user_assigned_identity.this.id
    }
    type = "UserAssigned"
  }
  storage_account_customer_managed_key = {
    key_name     = azurerm_key_vault_key.storage_key.name
    key_vault_id = azurerm_key_vault.storage_vault.id
  }
  key_vault_access_policy = {
    msi = {
      identity_principle_id = azurerm_user_assigned_identity.this.principal_id
      identity_tenant_id    = azurerm_user_assigned_identity.this.tenant_id
    }
  }
  storage_container = {
    blob_container = {
      name                  = "blob-container-${random_pet.this.id}"
      container_access_type = "private"
    }
  }
  storage_queue = {
    queue0 = {
      name = "queue-${random_pet.this.id}"
    }
  }
  storage_table = {
    table0 = {
      name = "table${random_pet.this.id}"
    }
  }
}

module "container_apps" {
  source = "./modules/azure-container-apps"

  resource_group_name                                = azurerm_resource_group.test.name
  location                                           = azurerm_resource_group.test.location
  log_analytics_workspace_name                       = "loganalytics-${random_id.rg_name.hex}"
  container_app_environment_name                     = "example-env-${random_id.env_name.hex}"
  container_app_environment_infrastructure_subnet_id = azurerm_subnet.subnet.id

  container_apps = {
    nginx = {
      name          = "nginx"
      revision_mode = "Single"

      template = {
        containers = [
          {
            name   = "nginx"
            memory = "0.5Gi"
            cpu    = 0.25
            image  = "${azurerm_container_registry.acr.login_server}/nginx"
          }
        ]
      }
      ingress = {
        allow_insecure_connections = false
        external_enabled           = true
        target_port                = 80
        traffic_weight = {
          latest_revision = true
          percentage      = 100
        }
      }
      registry = [
        {
          server               = azurerm_container_registry.acr.login_server
          username             = azurerm_container_registry_token.pulltoken.name
          password_secret_name = "secname"
        }
      ]
    }
  }

  container_app_secrets = {
    nginx = [
      {
        name  = "secname"
        value = azurerm_container_registry_token_password.pulltokenpassword.password1[0].value
      }
    ]
  }
  depends_on = [null_resource.docker_push]
}

module "openai" {
  source              = "./modules/azure-openai"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  private_endpoint = {
    "pe_endpoint" = {
      private_dns_entry_enabled       = true
      dns_zone_virtual_network_link   = "dns_zone_link"
      is_manual_connection            = false
      name                            = "pe_one"
      private_service_connection_name = "pe_one_connection"
      subnet_name                     = "subnet0"
      vnet_name                       = module.vnet.vnet_name
      vnet_rg_name                    = azurerm_resource_group.this.name
    }
  }
  deployment = {
    "text-embedding-ada-002" = {
      name          = "text-embedding-ada-002"
      model_format  = "OpenAI"
      model_name    = "text-embedding-ada-002"
      model_version = "2"
      scale_type    = "Standard"
    }
  }
  depends_on = [
    azurerm_resource_group.this,
    module.vnet
  ]
}