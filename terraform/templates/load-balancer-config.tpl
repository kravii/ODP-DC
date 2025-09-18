---
# Load Balancer Configuration for API Server
cluster_name: "${cluster_name}"
api_server_endpoint: "${control_plane_ips[0]}"
api_server_port: ${api_server_port}

# Control Plane Nodes for Load Balancing
control_plane_nodes:
%{ for i, ip in control_plane_ips ~}
  - ip: "${ip}"
    port: ${api_server_port}
%{ endfor ~}

# Load Balancer Type (nginx, haproxy, or keepalived)
load_balancer_type: "nginx"

# Health Check Configuration
health_check:
  enabled: true
  interval: 10
  timeout: 5
  retries: 3
  port: ${api_server_port}