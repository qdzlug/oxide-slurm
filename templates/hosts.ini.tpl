[head_node]
head ansible_host=${headnode_ip} ansible_user=ubuntu ansible_become=true ansible_become_method=sudo ansible_python_interpreter=/usr/bin/python3 ansible_become_user=root

[compute]
%{ for ip in compute_ips ~}
compute-${ip} ansible_host=${ip} ansible_user=ubuntu ansible_become=true ansible_become_method=sudo ansible_python_interpreter=/usr/bin/python3 ansible_become_user=root
%{ endfor ~}
