# Slurm Cluster Terraform Deployment

This project uses Terraform with the Oxide provider to deploy a Slurm cluster in the cloud. The Terraform configuration creates the following resources:

- **Project Data:** Fetches project information.
- **SSH Key:** Creates an SSH key resource for instance access.
- **VPC and Subnet:** Sets up a Virtual Private Cloud (VPC) and selects the default subnet.
- **Instance Disks:** Provisions disks for compute nodes.
- **Compute Instances:** Deploys the required number of compute instances with the Oxide provider.
- **External IPs:** Retrieves external IP addresses for the deployed instances.
- **Firewall Rules:** Creates firewall rules to allow internal cluster traffic (all protocols) and SSH access from anywhere.
- **Inventory File:** Generates an Ansible inventory file (`hosts.ini`) based on the external IPs of the deployed instances.

## Directory Structure

A typical directory structure for the Terraform project might look like:

```
terraform/
├── main.tf               # Main Terraform configuration file
├── variables.tf          # Variable definitions
├── outputs.tf            # Output definitions (e.g., node IPs)
├── terraform.tfvars      # Variable values specific to your environment
├── README.md             # This file
└── templates/
    └── hosts.ini.tpl     # Template to generate the Ansible hosts.ini file
```

## Prerequisites

- **Terraform v1.0 or later** is installed.
- Access to the Oxide provider (you may need appropriate credentials/configuration).
- The necessary variable values are provided (e.g., project name, public SSH key, instance count, VPC information, etc.).
- [Optional] `jq` is installed if you use any shell scripts to process Terraform outputs.

## Usage

1. **Initialize Terraform:**

   ```bash
   terraform init
   ```

2. **Review the Execution Plan:**

   ```bash
   terraform plan
   ```

3. **Apply the Configuration:**

   ```bash
   terraform apply -auto-approve
   ```

   This will deploy the VPC, instances, firewall rules, and other resources. The Ansible inventory file (`hosts.ini`) will be generated in the project root directory based on the external IP addresses of your instances.

4. **Check Outputs:**

   The output variable `slurm_node_ips` (and others, if defined) will list the external IP addresses of the instances.

   ```bash
   terraform output slurm_node_ips
   ```

## Terraform Variables

Variables are defined in `variables.tf` and typically include:

- `project_name`: Name of the Oxide project.
- `public_ssh_key`: Your SSH public key.
- `vpc_description`, `vpc_name`, `vpc_dns_name`: Details for the VPC.
- `instance_count`: Number of compute instances.
- `instance_prefix`: Prefix for instance names.
- `disk_size`: Size of disks for compute nodes.
- `ubuntu_image_id`: The source image UUID for Ubuntu.
- Other variables as needed for your environment.

You can override variable values using a `terraform.tfvars` file or via the command line.

## Firewall Rules

The Terraform configuration includes two firewall rule resources:

- **Internal Traffic Rule:**  
  Allows all TCP, UDP, and ICMP traffic between internal nodes. This rule targets the default subnet of your VPC.

- **SSH Rule:**  
  Allows inbound SSH traffic (TCP port 22) from anywhere by using an IP network filter with `0.0.0.0/0`.

## Ansible Inventory File

The `local_file` resource uses the template file `templates/hosts.ini.tpl` to generate an inventory file (`hosts.ini`). This file groups the head node and compute nodes, and is used by your Ansible playbooks to further configure the cluster.

## Additional Notes

- **Firewall Rule Targeting:**  
  The internal traffic rule uses the VPC and subnet names from your other Terraform resources to ensure proper targeting.
- **Node Naming:**  
  The first instance (index 0) is designated as the head node, and the remaining instances become compute nodes.
- **Post-deployment:**  
  After Terraform completes, you can run your Ansible playbook to install and configure Slurm on the deployed nodes.

## Troubleshooting

- If you add new output variables (like `slurm_node_ips`), make sure to run `terraform apply` so that the state file is updated.
- Use `terraform plan` to review changes before applying.
- Verify that your firewall rules and instance configurations match your cluster’s requirements.

## License

This project is provided under the [MIT License](LICENSE) (or another license of your choice).