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
variable ENABLE_HIGH_PERFORMANCE {
    type        = bool
    default     = false
}
variable "subnets" {
    description = "List of subnets to create"
    type = list(object({
        name = string
        zone = string
        vpc_id = string
        cidr = string
        public_gateway_id = string
    }))
    default = [
        {
          name = "subnet-1"
          zone = "us-south-1"
          vpc_id = "vpc-1"
          cidr = "10.0.0.0/29"
        },{
          name = "subnet-2"
          zone = "us-south-1"
          vpc_id = "vpc-1"
          cidr = "10.0.0.8/29"
        }
    ]
}

variable machines {
    description = "List of vm for control plane"
    type = list(object({
        name = string
        disksSize = number
        hProfile= string
        lProfile= string
        imageId= string 
        subnetIndex = number
    }))
    default = [
        {
          name = "COBOCRSPWEB04"
          disksSize    = 150
          hProfile = "mx2-2x16"
          lProfile = "cx2-2x4"
          imageId = "none"
          subnetIndex = 0
        },{
          name = "COBOCRSDWEB05"
          disksSize    = 127
          hProfile = "bx2-4x16"
          lProfile = "cx2-2x4"
          imageId = "none"
          subnetIndex = 1
        }
    ]
}