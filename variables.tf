variable "main_region" {
  type        = string
  description = "primary region of deployments for account (most common region in account)"
}

variable "scheduled_run" {
  type        = string
  description = "when the EventBridge even is ran (this should be ran DAILY and I wouldn't change it.)"
  default     = "rate(1 day)"
}

variable "days" {
  type        = string
  description = "days to check for ebs volumes unused (please -days_until_removed from this)"
}

variable "days_until_removed" {
  type        = string
  description = "tags volumes this many days out, so on this day they will be removed"
}

variable "exemption_tag_value" {
  type        = string
  description = "the value the lambda looks for to exempt from removing at all. if a volume has this tag it is considered undeletable"
  default     = "no-auto-removal"
}

variable "ebs_sns_name" {
  type        = string
  description = "name of the sns topic that sends ebs auto removal reports"
}

variable "ebs_cleanup_email" {
  type        = list(string)
  description = "emails for sns notification (current max is 2)"
}

variable "regions" {
  description = "the usual regions customer has resources in, as to check in this case for EBS volumes"
  type        = list(string)
}

variable "ebs_cleanup_email" {
  type    = list(string)
  default = []
}

variable "lambda_exec_role" {
  description = "this is the managed role by aws that is responsible for basic lambda execution permissions"
  type        = string
  default     = "AWSLambdaBasicExecutionRole"
}

variable "lambda_zip_name" {
  description = "full name of the .zip file that contains the binaries from the .NET zip file created"
  type        = string
}
