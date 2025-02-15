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
variable RESOURCE_GROUP {
    type        = string
    default     = "vpc-demo-rg"
}
variable ENABLE_HIGH_PERFORMANCE {
    type        = bool
    default     = false
}
variable WORKSPACE_ID {
    type        = string  
    default = "us-east.workspace.test-vpc.4781e21c"
}
variable MACHINES {
    description = "List of vm for control plane"
    type = list(object({
        name = string,
        hProfile= string,
        lProfile= string,
    }))
    default = [
        {
          name = "test-machine",
          hProfile = "mx2-2x16",
          lProfile = "cx2-2x4",
        }
    ]
}