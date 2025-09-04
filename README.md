# Deploying HPC Clusters to an Oxide Rack

This project demonstrates complete end-to-end solutions for deploying HPC clusters to an [Oxide](https://oxide.computer) rack. 
It supports both [Slurm](https://slurm.schedmd.com/documentation.html) and [Flux](https://flux-framework.org/) workload managers.
It uses [**Terraform**](https://www.terraform.io/) or [OpenTofu](https://opentofu.org/) to provision infrastructure on an Oxide Rack 
(including VPC, instances, and disks) and [**Ansible**](https://docs.ansible.com/) to configure the cluster.

## Project Overview

- [**Terraform Module**](./terraform/README.md):  
  - Provisions cloud infrastructure (VPC, subnets, compute instances, disks).
  - Generates an Ansible inventory file (`hosts.ini`) based on instance IP addresses.
  - See the [Terraform README](./terraform/README.md) for details.

- [**Ansible Module**](./ansible/README.md):  
  - Supports both Slurm and Flux cluster deployments through separate playbooks
  - Installs required packages and configures users/groups  
  - Sets up NFS for shared package distribution
  - Manages Munge authentication across the cluster
  - Builds and configures the selected workload manager
  - Performs verification tasks to ensure cluster health
  - See the [Ansible README](./ansible/README.md) for details.

## Architecture

1. **Infrastructure Provisioning (Terraform):**  
   Terraform provisions a VPC, deploys compute instances (with the first instance designated as the head node and the remaining as compute nodes), creates disks, and configures firewall rules. It also generates an Ansible inventory file for further configuration.

2. **Cluster Configuration (Ansible):**  
   Ansible configures the OS on each node, sets up NFS for shared package distribution, installs and configures Munge for authentication, builds and installs the selected workload manager (Slurm or Flux), and verifies cluster health.

## How to Use

### Quick Start (Recommended)

1. **Prerequisites**
   - Ensure you have the necessary credentials and access to your Oxide Rack
   - Install Terraform/OpenTofu and Ansible
   - Clone this repository: `git clone https://github.com/qdzlu/oxide-slurm.git`

2. **Interactive Setup**
   ```bash
   ./setup.sh configure
   ```
   This will guide you through:
   - Cluster type selection (Slurm vs Flux)
   - Node count configuration
   - Spack mirror setup (simplifies package installation)
   - Generates all required configuration files

3. **Infrastructure Provisioning**
   ```bash
   cd terraform
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your Oxide Rack details
   terraform init
   terraform apply
   ```

4. **Deploy Cluster**
   ```bash
   ./setup.sh deploy
   ```

### Manual Configuration (Advanced)

If you prefer manual setup:

1. **Prerequisites**
   - Install Terraform or OpenTofu and ensure it's configured to work with your Oxide Rack
   - Install Ansible on your local machine or a control node

2. **Infrastructure with Terraform**
   - Navigate to the Terraform directory: `cd terraform`
   - Download an Ubuntu base image and [upload it](https://docs.oxide.computer/guides/creating-and-sharing-images) to the Oxide Rack
   - Edit `terraform.tfvars` with your Oxide Rack credentials and configuration
   - Initialize and apply: `terraform init && terraform apply`
   - This creates your VPC, instances, firewall rules, and generates the `hosts.ini` file

3. **Configure Spack Mirrors (Optional)**
   - Edit `ansible/group_vars/all.yml` to configure Spack mirror URLs
   - Leave empty for direct internet downloads (slower but more reliable)

4. **Deploy with Ansible**
   - Navigate to the Ansible directory: `cd ansible`
   - **For Slurm cluster:** `ansible-playbook -i inventory/hosts.ini playbooks/slurm-cluster.yml`
   - **For Flux cluster:** `ansible-playbook -i inventory/hosts.ini playbooks/flux-cluster.yml`

### Setup Script Commands

```bash
./setup.sh configure     # Interactive configuration
./setup.sh deploy        # Deploy cluster
./setup.sh status        # Show current config
./setup.sh validate      # Check prerequisites
./setup.sh clean         # Remove configuration
./setup.sh help          # Show help
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
oxide-slurm/
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars
│   └── README.md         # Terraform README (detailed instructions)
├── ansible/
│   ├── playbooks/
│   │   ├── slurm-cluster.yml    # Slurm deployment playbook
│   │   └── flux-cluster.yml     # Flux deployment playbook
│   ├── inventory/
│   │   └── hosts.ini            # Generated by Terraform
│   ├── roles/
│   │   ├── common/              # Shared infrastructure setup
│   │   ├── nfs/                 # Shared storage configuration
│   │   ├── munge/               # Authentication setup
│   │   ├── slurm/               # Slurm workload manager
│   │   ├── flux/                # Flux workload manager
│   │   └── verification/        # Health checks
│   └── README.md                # Ansible README (detailed instructions)
└── README.md                    # This high-level README
```

## License

This project is released under the [MIT License](LICENSE).

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## Contact

For questions or feedback, please contact jay@jayschmidt.us.