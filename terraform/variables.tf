variable "project_name" {
  description = "Oxide project name"
  type        = string
}

variable "vpc_name" {
  description = "VPC name"
  type        = string
}

variable "vpc_dns_name" {
  description = "DNS name for VPC"
  type        = string
}

variable "vpc_description" {
  description = "Description for VPC"
  type        = string
}

variable "instance_count" {
  description = "Number of compute nodes (1 controller + N workers)"
  type        = number
}

variable "instance_prefix" {
  description = "Prefix for instance names"
  type        = string
}

variable "memory" {
  description = "Amount of memory for instances"
  type        = number
}

variable "ncpus" {
  description = "Number of CPUs for instances"
  type        = number
}

variable "disk_size" {
  description = "Size of each instance disk (GB)"
  type        = number
}

variable "ubuntu_image_id" {
  description = "UUID of the Ubuntu image to use"
  type        = string
}

variable "public_ssh_key" {
  description = "Public SSH key for authentication"
  type        = string
}
