variable "name" {
  type        = string
  description = "Cluster Name"
}
variable "vpc_id" {
  type        = string
  description = "ECS Cluster VPC"
}

variable "enable_cross_zone_load_balancing" {
  type        = bool
  description = "Enable Cross Zone Load Balance"
  default     = true
}

variable "private_subnets" {
  type    = list
  default = []
}

variable "public_subnets" {
  type    = list
  default = []
}

variable "idle_timeout" {
  type    = number
  default = 60
}

variable "log_bucket_name" {
  type = string
}

variable "tags" {
  type    = map
  default = {}
}
