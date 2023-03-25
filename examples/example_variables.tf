#add the below variables to your root terraform variables.tf file your using.

variable "ebs_regions" {
  type        = list(string)
  description = "A list of common regions where EBS volumes may have been created"
  default     = []
}

variable "exemption_tag_value" {
  type        = string
  description = "the tag value that exempts the EBS volume from the removal process"
  default     = ""
}

variable "days" {
  type        = string
  description = "amount of days that ebs volumes are tagged for deletion (not deleted, add -days_until_removed)"
  default     = ""
}

variable "days_until_removed" {
  type        = string
  description = "amount of days that ebs volumes are deleted after being tagged for deletion"
  default     = ""
}

variable "ebs_sns_name" {
  type        = string
  description = "name of the ebs sns topic for the removal automation lambda"
  default     = ""
}

variable "ebs_cleanup_email" {
  type    = list(string)
  default = []
}
