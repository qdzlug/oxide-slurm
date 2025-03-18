# Slurm Cluster Setup with Ansible

This project uses Ansible to deploy and configure a Slurm cluster with a shared NFS-based package distribution system. It is designed to set up both head (controller) and compute nodes, manage user/group configuration, distribute the Munge key, build and install Slurm, and verify that the cluster is operational.

## Directory Structure

The project is organized into roles, each handling a specific aspect of the cluster setup:

```
ansible_project/
├── playbook.yml                  # Main playbook that includes all roles
├── inventory/
│   └── hosts.ini                 # Inventory file defining head_node and compute groups
├── README.md                     # This file
└── roles/
    ├── common/
    │   ├── tasks/
    │   │   └── main.yml          # Tasks for package installation, host file configuration, and user/group setup
    │   ├── vars/
    │   │   └── main.yml          # Common variables
    │   ├── templates/            # Templates used by common tasks (if any)
    │   └── handlers/             # Handlers for common tasks (e.g., restarting services)
    ├── nfs/
    │   ├── tasks/
    │   │   └── main.yml          # Tasks for configuring the NFS share on the head node and mounting on compute nodes
    │   ├── vars/
    │   │   └── main.yml          # NFS-specific variables (inherits from common)
    │   └── handlers/
    │       └── main.yml          # Handler to restart the NFS service
    ├── munge/
    │   ├── tasks/
    │   │   └── main.yml          # Tasks for Munge key generation and distribution
    │   └── vars/
    │       └── main.yml          # Munge-specific variables (inherits from common)
    ├── slurm/
    │   ├── tasks/
    │   │   └── main.yml          # Tasks to download, build, package (via fpm), install and configure Slurm
    │   ├── vars/
    │   │   └── main.yml          # Slurm-specific variables (inherits from common)
    │   └── templates/
    │       └── slurm.conf.j2     # Jinja2 template for generating slurm.conf dynamically
    └── verification/
        ├── tasks/
        │   └── main.yml          # Tasks to verify node readiness, service status, and connectivity
        └── vars/
            └── main.yml          # Verification-specific variables (inherits from common)
```

## Requirements

- **Ansible 2.9+ or later** (Tested with Ansible 2.9 and later)
- Access to the target nodes with appropriate privileges (using `become`)
- A valid inventory file (`inventory/hosts.ini`) defining your head node and compute nodes.
- Necessary software packages on target nodes (e.g., `apt` for Ubuntu).
- An NFS server must be configured on the head node, and compute nodes must be able to mount the NFS share.
- The Slurm source package and fpm must be accessible on the head node.

## Variables

Common variables are defined in `roles/common/vars/main.yml` and include:

- `slurm_version`: Version of Slurm to deploy.
- `slurm_db_user`, `slurm_db_pass`, `slurm_db_name`: Database credentials for Slurm accounting.
- `munge_key_path`: Location of the Munge key.
- `slurm_config_path`: Directory for Slurm configuration files.
- `slurm_build_path`: Temporary directory for building Slurm.
- `slurm_package_repo`: Directory for storing the Slurm .deb package.
- `slurm_nfs_share` / `slurm_nfs_mount`: NFS share mount point.
- `slurm_partition_name`: Name of the compute partition.
- `munge_nfs_path`: Path within the NFS share for the Munge key.
- `slurm_control_host`: IP address of the head node, automatically determined from the first host in the `head_node` group.

## Usage

1. **Prepare Your Inventory**  
   Create or update your `inventory/hosts.ini` file with the correct host definitions. For example:

   ```ini
   [head_node]
   slurm-node-1 ansible_host=172.21.252.61 ansible_user=ubuntu ansible_become=true ansible_become_method=sudo ansible_python_interpreter=/usr/bin/python3

   [compute]
   slurm-node-2 ansible_host=172.21.252.99 ansible_user=ubuntu ansible_become=true ansible_become_method=sudo ansible_python_interpreter=/usr/bin/python3
   slurm-node-3 ansible_host=172.21.252.68 ansible_user=ubuntu ansible_become=true ansible_become_method=sudo ansible_python_interpreter=/usr/bin/python3
   slurm-node-4 ansible_host=172.21.252.75 ansible_user=ubuntu ansible_become=true ansible_become_method=sudo ansible_python_interpreter=/usr/bin/python3
   slurm-node-5 ansible_host=172.21.252.54 ansible_user=ubuntu ansible_become=true ansible_become_method=sudo ansible_python_interpreter=/usr/bin/python3

   [slurm_cluster:children]
   head_node
   compute
   ```

2. **Run the Playbook**  
   From your project directory, run:
   ```bash
   ansible-playbook -i inventory/hosts.ini playbook.yml
   ```

3. **Verify Deployment**  
   The playbook will:
   - Install required packages and configure users/groups.
   - Configure the NFS share on the head node and mount it on compute nodes.
   - Manage the Munge key for cluster-wide authentication.
   - Build and install Slurm on the head node, distribute the configuration, and install the package on compute nodes.
   - Run verification tasks to ensure all nodes and services are ready.
   - Finally, print out SSH commands for easy access to each node.

## Troubleshooting

- **NFS Issues:**  
  Verify the NFS server is running on the head node and that compute nodes can mount the share.
- **Munge Key Problems:**  
  Check that the Munge key is correctly generated on the head node and distributed to compute nodes.
- **Slurm Service Status:**  
  Use `scontrol show nodes` and `sinfo` on the head node to verify cluster status. The verification tasks in the playbook also help identify issues.
- **Verbose Output:**  
  Run the playbook with increased verbosity (`-vvv`) to diagnose problems.

## Additional Information

- **Roles:**  
  Each role in the `roles/` directory is responsible for a different aspect of the deployment:
  - **common:** General setup, package installation, host file configuration, and user/group setup.
  - **nfs:** Configuring the NFS share on the head node and mounting it on compute nodes.
  - **munge:** Managing Munge key generation and distribution.
  - **slurm:** Downloading, building, packaging, installing, and configuring Slurm.
  - **verification:** Validating that services are running and nodes are reachable.

- **Templates:**  
  The `slurm.conf.j2` template in `roles/slurm/templates/` is used to generate the Slurm configuration file dynamically, using Ansible facts to automatically detect hardware on each node.
