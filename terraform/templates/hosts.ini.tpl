[head_node]
slurm-node-1 ansible_host=${headnode_ip} ansible_user=ubuntu ansible_become=true ansible_become_method=sudo ansible_python_interpreter=/usr/bin/python3 ansible_become_user=root

[compute]
%{ for node in compute_nodes ~}
${node.name} ansible_host=${node.ip} ansible_user=ubuntu ansible_become=true ansible_become_method=sudo ansible_python_interpreter=/usr/bin/python3 ansible_become_user=root
%{ endfor ~}

[slurm_cluster:children]
head_node
compute
