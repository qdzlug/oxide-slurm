#!/bin/bash

# Oxide HPC Cluster Setup Script
# Simplifies configuration and deployment of Slurm/Flux clusters

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/.cluster-config"

# Default values
DEFAULT_CLUSTER_TYPE="slurm"
DEFAULT_NODE_COUNT="4"
DEFAULT_USE_SPACK_MIRROR="false"
DEFAULT_SPACK_MIRROR_HOST=""

# Helper functions
log() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Load existing configuration if available
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        log "Loading existing configuration from $CONFIG_FILE"
        source "$CONFIG_FILE"
    fi
}

# Save configuration
save_config() {
    cat > "$CONFIG_FILE" << EOF
# Oxide HPC Cluster Configuration
CLUSTER_TYPE="$CLUSTER_TYPE"
NODE_COUNT="$NODE_COUNT"
USE_SPACK_MIRROR="$USE_SPACK_MIRROR"
SPACK_MIRROR_HOST="$SPACK_MIRROR_HOST"
SPACK_SOURCE_MIRROR="$SPACK_SOURCE_MIRROR"
SPACK_BINARY_MIRROR="$SPACK_BINARY_MIRROR"
TERRAFORM_CONFIGURED="$TERRAFORM_CONFIGURED"
EOF
    log "Configuration saved to $CONFIG_FILE"
}

# Interactive configuration
configure_cluster() {
    echo -e "${BLUE}=== Oxide HPC Cluster Setup ===${NC}"
    echo "This script will help you configure and deploy your HPC cluster."
    echo ""

    # Cluster type selection
    echo "1. Cluster Type Configuration"
    echo "   [1] Slurm (traditional HPC workload manager)"
    echo "   [2] Flux (modern graph-based scheduler)"
    echo ""
    read -p "Select cluster type (1 or 2) [default: 1]: " cluster_choice
    case "${cluster_choice:-1}" in
        1) CLUSTER_TYPE="slurm" ;;
        2) CLUSTER_TYPE="flux" ;;
        *) error "Invalid choice. Please select 1 or 2."; exit 1 ;;
    esac
    success "Cluster type: $CLUSTER_TYPE"
    echo ""

    # Node count
    read -p "Number of compute nodes (excluding head node) [default: $DEFAULT_NODE_COUNT]: " NODE_COUNT
    NODE_COUNT="${NODE_COUNT:-$DEFAULT_NODE_COUNT}"
    if ! [[ "$NODE_COUNT" =~ ^[0-9]+$ ]] || [[ "$NODE_COUNT" -lt 1 ]]; then
        error "Node count must be a positive integer"
        exit 1
    fi
    success "Total nodes: $((NODE_COUNT + 1)) (1 head + $NODE_COUNT compute)"
    echo ""

    # Spack mirror configuration
    echo "2. Spack Package Mirror Configuration"
    echo "   Spack mirrors can significantly speed up package installation."
    echo "   Choose one of the following options:"
    echo ""
    echo "   [1] No mirror - Download packages directly from internet (slower, more reliable)"
    echo "   [2] Use existing Spack mirror server"
    echo "   [3] Public mirrors only (cache.spack.io, etc.)"
    echo ""
    read -p "Select option (1, 2, or 3) [default: 1]: " mirror_choice
    
    case "${mirror_choice:-1}" in
        1)
            USE_SPACK_MIRROR="false"
            SPACK_MIRROR_HOST=""
            SPACK_SOURCE_MIRROR=""
            SPACK_BINARY_MIRROR=""
            success "Configuration: Direct internet downloads"
            ;;
        2)
            USE_SPACK_MIRROR="true"
            read -p "Enter Spack mirror host IP/hostname: " SPACK_MIRROR_HOST
            if [[ -z "$SPACK_MIRROR_HOST" ]]; then
                error "Mirror host cannot be empty"
                exit 1
            fi
            SPACK_SOURCE_MIRROR="http://${SPACK_MIRROR_HOST}:8080/source/"
            SPACK_BINARY_MIRROR="http://${SPACK_MIRROR_HOST}:8080/binary/"
            success "Configuration: Using mirror at $SPACK_MIRROR_HOST"
            ;;
        3)
            USE_SPACK_MIRROR="public"
            SPACK_MIRROR_HOST=""
            SPACK_SOURCE_MIRROR=""
            SPACK_BINARY_MIRROR=""
            success "Configuration: Public mirrors only"
            ;;
        *)
            error "Invalid choice. Please select 1, 2, or 3."
            exit 1
            ;;
    esac
    echo ""

    # Terraform check
    TERRAFORM_CONFIGURED="false"
    if [[ -f "$SCRIPT_DIR/terraform/terraform.tfvars" ]]; then
        echo "3. Infrastructure Configuration"
        echo "   Existing terraform.tfvars found."
        read -p "Have you already configured and applied Terraform? (y/n) [default: n]: " terraform_done
        if [[ "${terraform_done:-n}" =~ ^[Yy] ]]; then
            TERRAFORM_CONFIGURED="true"
            success "Terraform configuration: Ready"
        else
            warn "You'll need to configure Terraform before deployment"
        fi
    else
        warn "No terraform.tfvars found. You'll need to set up Terraform first."
    fi
    echo ""
}

# Update Ansible configuration based on user choices
update_ansible_config() {
    log "Updating Ansible configuration..."

    # Create backup of existing config
    if [[ -f "$SCRIPT_DIR/ansible/group_vars/all.yml" ]]; then
        cp "$SCRIPT_DIR/ansible/group_vars/all.yml" "$SCRIPT_DIR/ansible/group_vars/all.yml.backup"
        log "Backed up existing all.yml to all.yml.backup"
    fi

    # Ensure group_vars directory exists in both locations
    mkdir -p "$SCRIPT_DIR/group_vars"
    mkdir -p "$SCRIPT_DIR/ansible/group_vars"
    
    # Generate new group_vars/all.yml in root (primary)
    cat > "$SCRIPT_DIR/group_vars/all.yml" << EOF
# Oxide HPC Cluster Configuration
# Generated by setup.sh on $(date)

# Spack Configuration
spack_user: spack
EOF

    # Add mirror configuration based on user choice
    if [[ "$USE_SPACK_MIRROR" == "true" ]]; then
        cat >> "$SCRIPT_DIR/ansible/group_vars/all.yml" << EOF
spack_source_mirror: $SPACK_SOURCE_MIRROR
spack_binary_mirror: $SPACK_BINARY_MIRROR
EOF
    elif [[ "$USE_SPACK_MIRROR" == "false" ]]; then
        cat >> "$SCRIPT_DIR/group_vars/all.yml" << EOF
# No custom mirrors configured - will use internet downloads
spack_source_mirror: ""
spack_binary_mirror: ""
EOF
    else # public mirrors only
        cat >> "$SCRIPT_DIR/group_vars/all.yml" << EOF
# Using public mirrors only
spack_source_mirror: "https://mirror.spack.io/source/"
spack_binary_mirror: "https://mirror.spack.io/binary/"
EOF
    fi

    # Add package configuration
    cat >> "$SCRIPT_DIR/group_vars/all.yml" << EOF

# Default package set for $CLUSTER_TYPE cluster
spack_packages:
  - gcc
  - openmpi
  - pmix
EOF

    if [[ "$CLUSTER_TYPE" == "flux" ]]; then
        echo "  - flux-core" >> "$SCRIPT_DIR/group_vars/all.yml"
    fi

    # Also copy to ansible/group_vars for compatibility
    cp "$SCRIPT_DIR/group_vars/all.yml" "$SCRIPT_DIR/ansible/group_vars/all.yml"
    
    success "Ansible configuration updated"
}

# Create or update inventory template
create_inventory_template() {
    if [[ ! -f "$SCRIPT_DIR/ansible/inventory/hosts.ini" ]]; then
        log "Creating inventory template..."
        mkdir -p "$SCRIPT_DIR/ansible/inventory"
        
        cat > "$SCRIPT_DIR/ansible/inventory/hosts.ini.template" << EOF
# Inventory Template - Update with actual IP addresses after Terraform deployment
# Or use the generated hosts.ini from Terraform output

[head_node]
cluster-head ansible_host=<HEAD_NODE_IP> ansible_user=ubuntu ansible_become=true ansible_python_interpreter=/usr/bin/python3

[compute]
EOF

        for i in $(seq 1 "$NODE_COUNT"); do
            echo "cluster-node-$i ansible_host=<COMPUTE_NODE_${i}_IP> ansible_user=ubuntu ansible_become=true ansible_python_interpreter=/usr/bin/python3" >> "$SCRIPT_DIR/ansible/inventory/hosts.ini.template"
        done

        cat >> "$SCRIPT_DIR/ansible/inventory/hosts.ini.template" << EOF

[cluster:children]
head_node
compute
EOF
        success "Inventory template created at ansible/inventory/hosts.ini.template"
    fi
}

# Deployment helper
deploy_cluster() {
    log "Starting cluster deployment..."

    if [[ "$TERRAFORM_CONFIGURED" != "true" ]]; then
        error "Terraform not configured. Please run 'cd terraform && terraform init && terraform apply' first."
        return 1
    fi

    if [[ ! -f "$SCRIPT_DIR/ansible/inventory/hosts.ini" ]]; then
        error "Inventory file not found. Make sure Terraform has generated hosts.ini or create it manually."
        return 1
    fi

    # Run appropriate playbook
    local playbook="$SCRIPT_DIR/${CLUSTER_TYPE}-cluster.yml"
    if [[ ! -f "$playbook" ]]; then
        error "Playbook not found: $playbook"
        return 1
    fi

    log "Deploying $CLUSTER_TYPE cluster..."
    cd "$SCRIPT_DIR"
    
    if ansible-playbook -i ansible/inventory/hosts.ini "$playbook"; then
        success "$CLUSTER_TYPE cluster deployed successfully!"
        echo ""
        echo "Next steps:"
        echo "1. SSH to your head node to test the cluster"
        echo "2. For Slurm: Try 'srun -N 2 hostname' to test job scheduling"
        echo "3. For Flux: Try 'flux run -N 2 hostname' to test job scheduling"
    else
        error "Deployment failed. Check the Ansible output above for details."
        return 1
    fi
}

# Validation helpers
validate_environment() {
    log "Validating environment..."
    
    # Check required tools
    local missing_tools=()
    
    if ! command -v ansible-playbook >/dev/null 2>&1; then
        missing_tools+=("ansible")
    fi
    
    if ! command -v terraform >/dev/null 2>&1 && ! command -v tofu >/dev/null 2>&1; then
        missing_tools+=("terraform or opentofu")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        error "Missing required tools: ${missing_tools[*]}"
        echo "Please install the missing tools and try again."
        return 1
    fi
    
    success "Environment validation passed"
}

# Help function
show_help() {
    cat << EOF
Oxide HPC Cluster Setup Script

Usage: $0 [COMMAND]

Commands:
    configure     Interactive configuration setup
    deploy        Deploy the cluster using current configuration
    validate      Validate environment and dependencies
    status        Show current configuration
    clean         Remove configuration and start over
    help          Show this help message

Examples:
    $0 configure     # Run interactive setup
    $0 deploy        # Deploy cluster with current config
    $0 status        # Show current settings

The script simplifies Spack mirror configuration, inventory management,
and deployment of Slurm/Flux clusters on Oxide racks.
EOF
}

# Status display
show_status() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        warn "No configuration found. Run '$0 configure' first."
        return 1
    fi
    
    load_config
    
    echo -e "${BLUE}=== Current Configuration ===${NC}"
    echo "Cluster Type: $CLUSTER_TYPE"
    echo "Node Count: $((${NODE_COUNT:-0} + 1)) (1 head + ${NODE_COUNT:-0} compute)"
    echo "Spack Mirror: $USE_SPACK_MIRROR"
    if [[ "$USE_SPACK_MIRROR" == "true" ]]; then
        echo "Mirror Host: $SPACK_MIRROR_HOST"
        echo "Source Mirror: $SPACK_SOURCE_MIRROR"
        echo "Binary Mirror: $SPACK_BINARY_MIRROR"
    fi
    echo "Terraform Ready: ${TERRAFORM_CONFIGURED:-false}"
    echo ""
    echo "Config file: $CONFIG_FILE"
    echo "Ansible config: $SCRIPT_DIR/ansible/group_vars/all.yml"
}

# Clean configuration
clean_config() {
    read -p "Remove all configuration and start over? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy] ]]; then
        rm -f "$CONFIG_FILE"
        rm -f "$SCRIPT_DIR/ansible/group_vars/all.yml.backup"
        success "Configuration cleaned"
    else
        log "Configuration preserved"
    fi
}

# Main script logic
main() {
    case "${1:-help}" in
        configure)
            validate_environment
            load_config
            configure_cluster
            save_config
            update_ansible_config
            create_inventory_template
            echo ""
            success "Configuration complete!"
            echo "Next steps:"
            echo "1. Configure Terraform: cd terraform && cp terraform.tfvars.example terraform.tfvars"
            echo "2. Apply Terraform: terraform init && terraform apply"  
            echo "3. Deploy cluster: $0 deploy"
            ;;
        deploy)
            validate_environment
            load_config
            deploy_cluster
            ;;
        validate)
            validate_environment
            ;;
        status)
            show_status
            ;;
        clean)
            clean_config
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"