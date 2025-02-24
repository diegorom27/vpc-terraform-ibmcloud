terraform {
  required_providers {
    ibm = {
      source = "ibm-cloud/ibm"
    }
  }
}

resource "ibm_satellite_location" "satellite-location-demo" {
  location          = "satellite-location-demo"
  zones             = var.location_zones
  managed_from      = var.datacenter-satellite
  resource_group_id = var.resource_group
  coreos_enabled   = false
}

data "ibm_satellite_attach_host_script" "script" {
  location          = ibm_satellite_location.satellite-location-demo.location
  host_provider     = "ibm"
  coreos_host      = false

  depends_on = [ ibm_satellite_location.satellite-location-demo ]
}