# Makefile for oxide-slurm project

SHELL = /bin/bash

# Extracted variables from terraform.tfvars
project_name := $(shell grep '^project_name' terraform/terraform.tfvars | sed 's/.*= *"\(.*\)"/\1/')
vpc_name       := $(shell grep '^vpc_name' terraform/terraform.tfvars | sed 's/.*= *"\(.*\)"/\1/')
instance_count := $(shell grep '^instance_count' terraform/terraform.tfvars | sed 's/.*= *\([0-9]*\).*/\1/')
ansible_user   := $(shell grep '^ansible_user' terraform/terraform.tfvars | sed 's/.*= *"\(.*\)"/\1/')

VENV = .venv
PYTHON = $(VENV)/bin/python3
PIP = $(VENV)/bin/pip
ANSIBLE_PLAYBOOK = $(VENV)/bin/ansible-playbook
ANSIBLE_LINT = $(VENV)/bin/ansible-lint
YAMLLINT = $(VENV)/bin/yamllint
TOFU = tofu

.PHONY: help venv deps lint validate show-vars infra-up deploy destroy clean provision

help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  venv            - Create and activate Python virtual environment with requirements"
	@echo "  deps            - Install Python and Ansible dependencies"
	@echo "  validate        - Validate OpenTofu configuration"
	@echo "  show-vars       - Display project variables from terraform.tfvars"
	@echo "  infra-up        - Stand up infrastructure using OpenTofu and wait for nodes"
	@echo "  deploy          - Deploy SLURM environment using Ansible"
	@echo "  provision       - Shortcut for ansible-playbook against generated inventory"
	@echo "  destroy         - Tear down infrastructure using OpenTofu"
	@echo "  lint            - Run linting tools on playbooks and Terraform"
	@echo "  clean           - Remove virtual environment and Terraform caches"

venv:
	@test -d $(VENV) || python3 -m venv $(VENV)
	$(PIP) install -U pip
	$(PIP) install -r requirements.txt
	$(VENV)/bin/ansible-galaxy collection install -r collections.yml || true

deps: venv

validate:
	cd terraform && $(TOFU) validate

show-vars:
	@set +H; \
	echo "Project Variables:"; \
	echo "  project_name: $(project_name)"; \
	echo "  vpc_name: $(vpc_name)"; \
	echo "  instance_count: $(instance_count)"; \
	echo "  ansible_user: $(ansible_user)";

infra-up:
	cd terraform && $(TOFU) init && $(TOFU) apply -auto-approve
	@echo "Waiting for hosts to respond to ansible-ping..."
	@until $(VENV)/bin/ansible all -m ping -i ansible/inventory/hosts.ini; do \
		echo "Hosts not reachable yet, waiting 10 seconds..."; \
		sleep 10; \
	done
	@echo "All hosts are reachable."

deploy:
	@echo "Deploying SLURM environment with Ansible..."
	$(ANSIBLE_PLAYBOOK) -i ansible/inventory/hosts.ini ansible/playbook.yml

provision:
	$(ANSIBLE_PLAYBOOK) -i ansible/inventory/hosts.ini ansible/playbook.yml

destroy:
	cd terraform && $(TOFU) destroy -auto-approve

lint:
	cd terraform && $(TOFU) fmt -recursive
	$(TOFU) fmt -check -recursive terraform
	$(ANSIBLE_LINT) ansible/
	$(YAMLLINT) ansible/

clean:
	rm -rf $(VENV)
	rm -rf terraform/.terraform
	rm -f terraform/terraform.tfstate*
