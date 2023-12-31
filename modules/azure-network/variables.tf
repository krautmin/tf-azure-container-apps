variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see https://aka.ms/avm/telemetry.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
}

variable "resource_group_name" {
  type        = string
  description = <<DESCRIPTION
The name of the resource group where the resources will be deployed.
DESCRIPTION
}

variable "name" {
  type        = string
  default     = "acctvnet"
  description = <<DESCRIPTION
The name of the virtual network to create.
DESCRIPTION
}

variable "address_space" {
  type        = string
  default     = "10.0.0.0/16"
  description = <<DESCRIPTION
The address space that is used by the virtual network.
DESCRIPTION
}

variable "address_spaces" {
  type        = list(string)
  default     = []
  description = <<DESCRIPTION
The list of the address spaces that is used by the virtual network.
DESCRIPTION
}

variable "dns_servers" {
  type        = list(string)
  default     = []
  description = <<DESCRIPTION
The DNS servers to be used with vNet.
If no values are specified, this defaults to Azure DNS.
DESCRIPTION
}

variable "vnet_location" {
  type        = string
  default     = null
  description = <<DESCRIPTION
The location/region where the virtual network is created. Changing this forces a new resource to be created.
DESCRIPTION
}

variable "subnet_delegation" {
  type = map(list(object({
    name = string
    service_delegation = object({
      name    = string
      actions = optional(list(string))
    })
  })))
  default     = {}
  description = <<DESCRIPTION
`service_delegation` blocks for `azurerm_subnet` resource, subnet names as keys, list of delegation blocks as value, more details about delegation block could be found at the [document](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet#delegation).
DESCRIPTION
  nullable    = false
}

variable "private_link_endpoint_network_policies_enabled" {
  type        = map(bool)
  default     = {}
  description = <<DESCRIPTION
A map with key (string) `subnet name`, value (bool) `true` or `false` to indicate enable or disable network policies for the private link endpoint on the subnet. Default value is false.
DESCRIPTION
}

variable "private_link_service_network_policies_enabled" {
  type        = map(bool)
  default     = {}
  description = <<DESCRIPTION
A map with key (string) `subnet name`, value (bool) `true` or `false` to indicate enable or disable network policies for the private link service on the subnet. Default value is false.
DESCRIPTION
}

variable "subnet_names" {
  type        = list(string)
  default     = ["subnet1"]
  description = <<DESCRIPTION
A list of public subnets inside the vNet.
DESCRIPTION
}

variable "subnet_prefixes" {
  type        = list(string)
  default     = ["10.0.1.0/24"]
  description = <<DESCRIPTION
The address prefix to use for the subnet.
DESCRIPTION
}

variable "subnet_service_endpoints" {
  type        = map(list(string))
  default     = {}
  description = <<DESCRIPTION
A map with key (string) `subnet name`, value (list(string)) to indicate enabled service endpoints on the subnet. Default value is [].
DESCRIPTION
}

variable "nsg_ids" {
  type = map(string)
  default = {
  }
  description = <<DESCRIPTION
A map of subnet name to Network Security Group IDs.
DESCRIPTION
}



variable "route_tables_ids" {
  type        = map(string)
  default     = {}
  description = <<DESCRIPTION
A map of subnet name to Route table ids.
DESCRIPTION
}

variable "ddos_protection_plan" {
  type = object({
    enable = bool
    id     = string
  })
  default     = null
  description = <<DESCRIPTION
The set of DDoS protection plan configuration.
DESCRIPTION
}

variable "tracing_tags_enabled" {
  type        = bool
  default     = false
  description = <<DESCRIPTION
Whether enable tracing tags that generated by BridgeCrew Yor.
DESCRIPTION
  nullable    = false
}

variable "tracing_tags_prefix" {
  type        = string
  default     = "avm_"
  description = <<DESCRIPTION
Default prefix for generated tracing tags.
DESCRIPTION
  nullable    = false

}


//required AVM interfaces

variable "diagnostic_settings" {
  type = map(object({
    name                                     = optional(string, null)
    log_categories_and_groups                = optional(set(string), ["allLogs"])
    metric_categories                        = optional(set(string), ["AllMetrics"])
    log_analytics_destination_type           = optional(string, "Dedicated")
    workspace_resource_id                    = optional(string, null)
    storage_account_resource_id              = optional(string, null)
    event_hub_authorization_rule_resource_id = optional(string, null)
    event_hub_name                           = optional(string, null)
    marketplace_partner_resource_id          = optional(string, null)
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for _, v in var.diagnostic_settings : contains(["Dedicated", "AzureDiagnostics"], v.log_analytics_destination_type)])
    error_message = "Log analytics destination type must be one of: 'Dedicated', 'AzureDiagnostics'."
  }
}


variable "role_assignments" {
  type = map(object({
    role_definition_id_or_name             = string
    principal_id                           = string
    description                            = optional(string, null)
    skip_service_principal_aad_check       = optional(bool, true)
    condition                              = optional(string, null)
    condition_version                      = optional(string, "2.0")
    delegated_managed_identity_resource_id = optional(string)
  }))
  default = {}
}

variable "lock" {
  type = object({
    name = optional(string, null)
    kind = optional(string, "None")


  })
  description = "The lock level to apply to the Virtual Network. Default is `None`. Possible values are `None`, `CanNotDelete`, and `ReadOnly`."
  default     = {}
  nullable    = false
  validation {
    condition     = contains(["CanNotDelete", "ReadOnly", "None"], var.lock.kind)
    error_message = "The lock level must be one of: 'None', 'CanNotDelete', or 'ReadOnly'."
  }
}


# Example resource implementation

variable "tags" {
  type = map(any)
  default = {

  }
  description = <<DESCRIPTION
The tags to associate with your network and subnets.
DESCRIPTION
}


variable "private_endpoints" {
  type = map(object({
    role_assignments                        = map(object({}))        # see https://azure.github.io/Azure-Verified-Modules/Azure-Verified-Modules/specs/shared/interfaces/#role-assignments
    lock                                    = object({})             # see https://azure.github.io/Azure-Verified-Modules/Azure-Verified-Modules/specs/shared/interfaces/#resource-locks
    tags                                    = optional(map(any), {}) # see https://azure.github.io/Azure-Verified-Modules/Azure-Verified-Modules/specs/shared/interfaces/#tags
    service                                 = string
    subnet_resource_id                      = string
    private_dns_zone_group_name             = optional(string, null)
    private_dns_zone_resource_ids           = optional(set(string), [])
    application_security_group_resource_ids = optional(set(string), [])
    network_interface_name                  = optional(string, null)
    ip_configurations = optional(map(object({
      name               = string
      group_id           = optional(string, null)
      member_name        = optional(string, null)
      private_ip_address = string
    })), {})
  }))
  default     = {}
  description = <<DESCRIPTION
A map of private endpoints to create on the Virtual Network. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.

- `name` - (Optional) The name of the private endpoint. One will be generated if not set.
- `role_assignments` - (Optional) A map of role assignments to create on the private endpoint. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time. See `var.role_assignments` for more information.
- `lock` - (Optional) The lock level to apply to the private endpoint. Default is `None`. Possible values are `None`, `CanNotDelete`, and `ReadOnly`.
- `tags` - (Optional) A mapping of tags to assign to the private endpoint.
- `subnet_resource_id` - The resource ID of the subnet to deploy the private endpoint in.
- `private_dns_zone_group_name` - (Optional) The name of the private DNS zone group. One will be generated if not set.
- `private_dns_zone_resource_ids` - (Optional) A set of resource IDs of private DNS zones to associate with the private endpoint. If not set, no zone groups will be created and the private endpoint will not be associated with any private DNS zones. DNS records must be managed external to this module.
- `application_security_group_resource_ids` - (Optional) A map of resource IDs of application security groups to associate with the private endpoint. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.
- `private_service_connection_name` - (Optional) The name of the private service connection. One will be generated if not set.
- `network_interface_name` - (Optional) The name of the network interface. One will be generated if not set.
- `location` - (Optional) The Azure location where the resources will be deployed. Defaults to the location of the resource group.
- `resource_group_name` - (Optional) The resource group where the resources will be deployed. Defaults to the resource group of the Key Vault.
- `ip_configurations` - (Optional) A map of IP configurations to create on the private endpoint. If not specified the platform will create one. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.
  - `name` - The name of the IP configuration.
  - `private_ip_address` - The private IP address of the IP configuration.
DESCRIPTION
}
