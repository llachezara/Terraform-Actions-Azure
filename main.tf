terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.13.0"
    }
  }
}

provider "azurerm" {
  subscription_id = "d349a8ff-3963-4c9f-811c-4bfb5bef027f"
  features {}
}

resource "random_integer" "ri" {
  min = 10000
  max = 99999
}

resource "azurerm_resource_group" "taskboard_rg" {
  name     = "${var.resource_group_name}${random_integer.ri.result}"
  location = var.resource_group_location
}

resource "azurerm_service_plan" "taskboard_sp" {
  name                = "${var.app_service_plan_name}-${random_integer.ri.result}"
  resource_group_name = azurerm_resource_group.taskboard_rg.name
  location            = azurerm_resource_group.taskboard_rg.location
  os_type             = "Linux"
  sku_name            = "F1"
}

resource "azurerm_mssql_server" "taskboard_server" {
  name                         = var.sql_server_name
  resource_group_name          = azurerm_resource_group.taskboard_rg.name
  location                     = azurerm_resource_group.taskboard_rg.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_login
  administrator_login_password = var.sql_admin_password
}

resource "azurerm_mssql_database" "taskboard_db" {
  name           = var.sql_database_name
  server_id      = azurerm_mssql_server.taskboard_server.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  max_size_gb    = 2
  sku_name       = "Basic"
  zone_redundant = false
}

resource "azurerm_mssql_firewall_rule" "taskboard_sql_fr" {
  name             = var.firewall_rull_name
  server_id        = azurerm_mssql_server.taskboard_server.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_linux_web_app" "taskboard_wp" {
  name                = "${var.app_service_name}-${random_integer.ri.result}"
  resource_group_name = azurerm_resource_group.taskboard_rg.name
  location            = azurerm_service_plan.taskboard_sp.location
  service_plan_id     = azurerm_service_plan.taskboard_sp.id

  site_config {
    application_stack {
      dotnet_version = "6.0"
    }
    always_on = false
  }
  connection_string {
    name  = "DefaultConnection"
    type  = "SQLAzure"
    value = "Data Source=tcp:${azurerm_mssql_server.taskboard_server.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_server.taskboard_server.administrator_login_password};Trusted_Connection=False; MultipleActiveResultSets=True;"
  }
}

resource "azurerm_app_service_source_control" "taskboard_source_control" {
  app_id                 = azurerm_linux_web_app.taskboard_wp.id
  repo_url               = var.repo_URL
  branch                 = "main"
  use_manual_integration = true
}