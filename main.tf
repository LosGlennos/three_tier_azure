provider "azurerm" {
  version = "=1.44.00"
}

resource "azurerm_resource_group" resource_group {
  name     = var.provider_name
  location = var.location
}

resource "azurerm_virtual_network" virtual_network {
  name                = var.vn_name
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  address_space       = ["192.168.0.0/16"]
}

# Resources that should be available from the internet.
resource "azurerm_subnet" public_subnet {
  name                 = "public_subnet"
  resource_group_name  = azurerm_resource_group.resource_group.name
  virtual_network_name = azurerm_virtual_network.virtual_network.name
  address_prefix       = "192.168.0.0/24"
}

# Resources that does computing. Eg API's, workers etc.
resource "azurerm_subnet" application_subnet {
  name                 = "application_subnet"
  resource_group_name  = azurerm_resource_group.resource_group.name
  virtual_network_name = azurerm_virtual_network.virtual_network.name
  address_prefix       = "192.168.96.0/24"
}

# Databases 'n' stuff
resource "azurerm_subnet" data_subnet {
  name                 = "data_subnet"
  resource_group_name  = azurerm_resource_group.resource_group.name
  virtual_network_name = azurerm_virtual_network.virtual_network.name
  address_prefix       = "192.168.192.0/24"
}

# Create a public IP to assign to the application gateway
resource "azurerm_public_ip" example {
  name                = "public_ip"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  allocation_method   = "Dynamic"
}

resource "azurerm_application_gateway" "network" {
  name                = "application_gateway"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location

  sku {
    name     = "Standard_Small"
    tier     = "Standard"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "gateway_ip_configuration"
    subnet_id = azurerm_subnet.public_subnet.id
  }

  frontend_port {
    name = "public_port"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "frontend_ip_configuration"
    public_ip_address_id = azurerm_public_ip.example.id
  }

  # TODO: Check what this does
  backend_address_pool {
    name = "backend_address_pool"
  }

  # TODO: Check if https redirection is made here
  backend_http_settings {
    name                  = "backend_http_settings"
    cookie_based_affinity = "Disabled" # Disable sticky sessions
    path                  = "/path1/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 1
  }

  http_listener {
    name                           = "http_listener"
    frontend_ip_configuration_name = "frontend_ip_configuration"
    frontend_port_name             = "public"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "request_routing_rule"
    rule_type                  = "Basic"
    http_listener_name         = "http_listener"
    backend_address_pool_name  = "backend_address_pool"
    backend_http_settings_name = "backend_http_settings"
  }
}