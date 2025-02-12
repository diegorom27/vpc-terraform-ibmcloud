#variable ibmcloud_api_key {
#    description = "The IBM Cloud platform API key needed to deploy IAM enabled resources"
#    type        = string
#}
variable ibm_region {
    description = "IBM Cloud region where all resources will be deployed"
    type        = string
    default = "us-south"
    validation  {
      error_message = "Must use an IBM Cloud region. Use `ibmcloud regions` with the IBM Cloud CLI to see valid regions."
      condition     = can(
        contains([
          "au-syd",
          "jp-tok",
          "eu-de",
          "eu-gb",
          "us-south",
          "us-east"
        ], var.ibm_region)
      )
    }
}
variable BASENAME {
    type        = string
    default     = "test-amado"
  
}
variable "ZONE" {
    type        = string
    default     = "us-south-1"
  
}
variable datacenter {
    type        = string
    default     = "dal10"
}