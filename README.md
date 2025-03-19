# Slurm Cluster Deployment Project

This project demonstrates a complete end-to-end solution for deploying a [Slurm](https://slurm.schedmd.com/documentation.html)
cluster to an [Oxide](https://oxide.computer) rack. It uses [**Terraform**](https://www.terraform.io/) or 
[OpenTofu](https://opentofu.org/) to provision the necessary infrastructure on an Oxide Rack (including VPC, instances, and
disks) and [**Ansible**](https://docs.ansible.com/) to configure the cluster (building slurm, installing packages, 
setting up NFS, Munge, and Slurm, and verifying node readiness).

## Project Overview

- [**Terraform Module**](./terraform/README.md):  
  - Provisions cloud infrastructure (VPC, subnets, compute instances, disks).
  - Generates an Ansible inventory file (`hosts.ini`) based on instance IP addresses.
  - See the [Terraform README](./terraform/README.md) for details.

- [**Ansible Module**](./ansible/README.md):  
  - Installs required packages and configures users/groups.
  - Sets up an NFS share on the head (controller) node and mounts it on compute nodes.
  - Manages Munge key generation and distribution.
  - Downloads, builds, and installs Slurm on the head node and distributes its configuration to compute nodes.
  - Performs verification tasks to ensure the cluster is operational.
  - See the [Ansible README](./ansible/README.md) for details.

## Architecture

1. **Infrastructure Provisioning (Terraform):**  
   Terraform provisions a VPC, deploys compute instances (with the first instance designated as the head node and the remaining as compute nodes), creates disks, and configures firewall rules. It also generates an Ansible inventory file for further configuration.

2. **Cluster Configuration (Ansible):**  
   Ansible configures the operating system on each node, sets up NFS for shared package distribution, installs and configures Munge for authentication, builds and installs Slurm, creates and configures Mariadb to store accounting information,
    and verifies cluster health.

## How to Use

### 1. Prerequisites
- Ensure you have the necessary credentials and access to your Oxide Rack.
- Install Terraform or OpenTofu and ensure it's configured to work with your Oxide Rack.
- Install Ansible on your local machine or a control node.

### 2. Clone this Repository
```bash
git clone https://github.com/qdzlu/oxide-slurm.git
````

### 1. Provision Infrastructure with Terraform
- Navigate to the Terraform directory:
  ```bash
  cd terraform
  ```
- Download an Ubuntu base image and [upload it](https://docs.oxide.computer/guides/creating-and-sharing-images) 
to the Oxide Rack. Make note of the Image ID, as you will need this value in the `terraform.tfvars` file.

- Edit the `terraform.tfvars` file to set your Oxide Rack credentials and other variables.

- Initialize and apply the configuration:
  ```bash
  terraform init
  terraform apply
  ```
- This will create your VPC, instances, firewall rules, and generate the `hosts.ini` file in the project root.

### 4. Configure the Cluster with Ansible
- Navigate to the Ansible directory (or run from the project root if configured accordingly):
  ```bash
  cd ansible
  ```
- Run the Ansible playbook using the generated inventory file:
  ```bash
  ansible-playbook  playbook.yml
  ```

## Troubleshooting

- **Missing Template Files:**  
  If you encounter errors such as "Could not find or access 'slurm.conf.j2'", ensure that the template file exists in the expected location (`roles/slurm/templates/slurm.conf.j2`). Verify your directory structure and file paths.

- **Inventory Issues:**  
  Ensure that the generated `hosts.ini` file correctly groups head and compute nodes. The head node is used to configure and distribute the central `slurm.conf` file.

- **Service Failures:**  
  If Slurm services (such as `slurmdbd`, `slurmctld`, or `slurmd`) are not running, review the verification output and check logs on the affected nodes.

- **Detailed Debugging:**  
  Run Ansible with increased verbosity (e.g. `ansible-playbook -i ../hosts.ini playbook.yml -vvv`) to gather more details about any failures.

## Directory Structure

```
project-root/
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars
│   └── README.md         # Terraform README (detailed instructions)
├── ansible/
│   ├── playbook.yml
│   ├── inventory/hosts.ini   # Generated by Terraform
│   └── roles/
│       ├── common/
│       ├── nfs/
│       ├── munge/
│       ├── slurm/
│       └── verification/
│   └── README.md         # Ansible README (detailed instructions)
└── README.md             # This high-level README
```

## License

This project is released under the [MIT License](LICENSE).

## Contact

For questions or feedback, please contact jay@jayschmidt.us.