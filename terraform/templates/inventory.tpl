all:
  children:
    control_plane:
      hosts:
%{ for i, ip in control_plane_ips ~}
        ${cluster_name}-cp-${i + 1}:
          ansible_host: ${ip}
          ansible_user: ${ssh_user}
          ansible_port: ${ssh_port}
          ansible_ssh_private_key_file: ${ssh_private_key_path}
          node_role: control-plane
          node_index: ${i + 1}
          os_type: rocky_linux_9
%{ endfor ~}
    worker_nodes:
      hosts:
%{ for i, ip in worker_ips ~}
        ${cluster_name}-worker-${i + 1}:
          ansible_host: ${ip}
          ansible_user: ${ssh_user}
          ansible_port: ${ssh_port}
          ansible_ssh_private_key_file: ${ssh_private_key_path}
          node_role: worker
          node_index: ${i + 1}
          os_type: rocky_linux_9
%{ endfor ~}
    kubernetes_cluster:
      children:
        - control_plane
        - worker_nodes
      vars:
        api_server_endpoint: ${api_server_endpoint}
        cluster_name: ${cluster_name}
        ssh_user: ${ssh_user}
        ssh_port: ${ssh_port}
        ssh_private_key_path: ${ssh_private_key_path}