provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-static-web-demo"
  location = "East US"
}

resource "azurerm_storage_account" "storage" {
  name                     = "staticwebandy2026"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  static_website {
    index_document = "index.html"
  }
}

resource "azurerm_storage_blob" "index" {
  name                   = "index.html"
  storage_account_name   = azurerm_storage_account.storage.name
  storage_container_name = "$web"
  type                   = "Block"
  content_type           = "text/html"
  source_content         = "<h1>Hello from Terraform Azure Static Site</h1>"
}
# Azure Front Door Profile
# -----------------------------
resource "azurerm_cdn_frontdoor_profile" "fd_profile" {
  name                = "fd-profile-demo"
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Standard_AzureFrontDoor"
}

# -----------------------------
# Azure Front Door Endpoint
# -----------------------------
resource "azurerm_cdn_frontdoor_endpoint" "fd_endpoint" {
  name                     = "fd-endpoint-demo"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.fd_profile.id
}

# -----------------------------
# Origin Group
# -----------------------------
resource "azurerm_cdn_frontdoor_origin_group" "fd_origin_group" {
  name                     = "fd-origin-group"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.fd_profile.id

  load_balancing {
    sample_size = 4
    successful_samples_required = 3
  }

  health_probe {
    protocol = "Https"
    interval_in_seconds = 30
    request_type = "GET"
  }
}

# -----------------------------
# Origin (your storage account)
# -----------------------------
resource "azurerm_cdn_frontdoor_origin" "fd_origin" {
  name                          = "storage-origin"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.fd_origin_group.id

  host_name          = azurerm_storage_account.storage.primary_web_host
  origin_host_header = azurerm_storage_account.storage.primary_web_host
  http_port          = 80
  https_port         = 443
  certificate_name_check_enabled = false
  enabled            = true
}

# -----------------------------
# Route
# -----------------------------
resource "azurerm_cdn_frontdoor_route" "fd_route" {
  name                          = "fd-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.fd_endpoint.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.fd_origin_group.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.fd_origin.id]

  supported_protocols = ["Http", "Https"]
  patterns_to_match   = ["/*"]
  forwarding_protocol = "HttpsOnly"
  https_redirect_enabled = true
}