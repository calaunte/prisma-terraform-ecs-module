variable "cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "sg_name" {
  description = "Security group name for ECS cluster"
  type        = string
}

variable "domain_name" {
  description = "Domain name used for ELB"
  type        = string
}

variable "vpc_name" {
  description = "VPC Name"
  type        = string
}

variable "efs_name" {
  description = "Name of efs file system"
  type        = string
}

variable "elb_name" {
  description = "Name of classic load balancer"
  type        = string
}

variable "launch_config_name" {
  description = "Launch config name"
  type        = string
}

variable "image_id" {
  description = "Image id for launch configuration"
  type        = string
}

variable "cidr" {
  description = "CIDR range for VPC"
  type        = string
}

variable "public_subnets" {
  description = "Public subnet ranges for VPC"
  type        = list(string)
}

variable "private_subnets" {
  description = "Private subnet ranges for VPC"
  type        = list(string)
}

variable "azs" {
  description = "List of availability zones"
  type        = list(string)
}

variable "tags" {
  description = "key/values to apply as tags to resources"
  type        = map(any)
  default     = {}
}