# aws region
variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "ap-south-1"
}

# vpc name
variable "vpc_name" {
  description = "The name of the VPC"
  type        = string
  default     = "jerney-vpc"
}

# vpc cidr
variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# availability zones
variable "availability_zones" {
  description = "The availability zones to use for the VPC"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}

# private subnets
variable "private_subnets" {
  description = "The CIDR blocks for the private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

# public subnets
variable "public_subnets" {
  description = "The CIDR blocks for the public subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

# environment
variable "environment" {
  description = "The environment for the resources"
  type        = string
  default     = "dev"
}

# cluster name
variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
  default     = "jerney-cluster"
}

