terraform {
  required_version = ">= 1.0"

  required_providers {
    oxide = {
      source  = "oxidecomputer/oxide"
      version = "0.5.0"
    }
  }
}

provider "oxide" {}

# Fetch Project Info
data "oxide_project" "slurm" {
  name = var.project_name
}

# SSH Key for Instances
resource "oxide_ssh_key" "slurm" {
  name        = "slurm-sshkey"
  description = "SSH Key for Slurm Access"
  public_key  = var.public_ssh_key
}

# Fetch External IPs for Instances
data "oxide_instance_external_ips" "slurm" {
  for_each    = oxide_instance.compute
  instance_id = each.value.id
  
  depends_on = [oxide_instance.compute]
}

# VPC for Slurm Cluster
resource "oxide_vpc" "slurm" {
  project_id  = data.oxide_project.slurm.id
  description = var.vpc_description
  name        = var.vpc_name
  dns_name    = var.vpc_dns_name
}

# Default VPC Subnet
data "oxide_vpc_subnet" "slurm" {
  project_name = data.oxide_project.slurm.name
  vpc_name     = oxide_vpc.slurm.name
  name         = "default"
}

# Compute Node Disks
resource "oxide_disk" "compute_disks" {
  for_each = { for i in range(var.instance_count) : i => "disk-${var.instance_prefix}-${i + 1}" }

  project_id      = data.oxide_project.slurm.id
  description     = "Disk for instance ${each.value}"
  name            = each.value
  size            = var.disk_size
  source_image_id = var.ubuntu_image_id # Ubuntu Image UUID
}

resource "oxide_instance" "compute" {
  for_each = { for i in range(var.instance_count) : i => "${var.instance_prefix}-${i + 1}" }

  project_id       = data.oxide_project.slurm.id
  boot_disk_id     = oxide_disk.compute_disks[each.key].id
  description      = "Instance ${each.value}"
  name             = each.value
  host_name        = each.value
  memory           = var.memory
  ncpus            = var.ncpus
  start_on_create  = true
  disk_attachments = [oxide_disk.compute_disks[each.key].id]
  ssh_public_keys  = [oxide_ssh_key.slurm.id]

  # Base64 encoding required for Oxide API
  user_data = base64encode(<<-EOF
#!/bin/bash
set -e

# Wait for cloud-init to complete
cloud-init status --wait

# Configure sudo access
echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu
chmod 0440 /etc/sudoers.d/ubuntu

# Ensure SSH is running and configured
systemctl enable ssh
systemctl start ssh

# Signal completion
touch /var/lib/cloud/instance/boot-finished
EOF
  )

  external_ips = [
    {
      type = "ephemeral"
    }
  ]

  network_interfaces = [
    {
      subnet_id   = data.oxide_vpc_subnet.slurm.id
      vpc_id      = data.oxide_vpc_subnet.slurm.vpc_id
      description = "NIC for ${each.value}"
      name        = "nic-${each.value}"
    }
  ]
}

resource "local_file" "ansible_inventory" {
  filename = "${path.root}/../ansible/inventory/hosts.ini"
  content = templatefile("./templates/hosts.ini.tpl", {
    headnode_ip = data.oxide_instance_external_ips.slurm["0"].external_ips[0].ip,
    compute_nodes = [for i in range(1, var.instance_count) : {
      name = "${var.instance_prefix}-${i + 1}"
      ip   = data.oxide_instance_external_ips.slurm[tostring(i)].external_ips[0].ip
    }]
  })
}

# Debug output - show instance IDs
output "debug_instance_ids" {
  value = {
    for i in range(var.instance_count) :
    "${var.instance_prefix}-${i + 1}" => oxide_instance.compute[tostring(i)].id
  }
}

# Debug output - show all external IPs data
output "debug_external_ips_raw" {
  value = {
    for i in range(var.instance_count) :
    tostring(i) => data.oxide_instance_external_ips.slurm[tostring(i)]
  }
  sensitive = false
}

# Output External IPs of Instances
output "slurm_node_ips" {
  value = {
    for i in range(var.instance_count) : 
    "${var.instance_prefix}-${i + 1}" => data.oxide_instance_external_ips.slurm[tostring(i)].external_ips[0].ip
  }
}
