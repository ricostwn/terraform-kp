[monitoring_server]
monitoring ansible_host=${monitoring_server_ip} ansible_user=${ssh_user} internal_ip=${monitoring_server_internal_ip}

[web_servers]
%{ for server in web_servers ~}
${server.name} ansible_host=${server.ip} ansible_user=${ssh_user} internal_ip=${server.internal_ip}
%{ endfor ~}

[all:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
ansible_python_interpreter=/usr/bin/python3
