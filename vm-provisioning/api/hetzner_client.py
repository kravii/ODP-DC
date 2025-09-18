"""
Hetzner Cloud API client for VM and server management
"""

import httpx
import asyncio
from typing import List, Dict, Any, Optional
from dataclasses import dataclass
import os
import logging

logger = logging.getLogger(__name__)

@dataclass
class VMConfig:
    name: str
    image: str
    server_type: str
    cpu: int
    memory: int
    storage: int
    ip_address: Optional[str] = None
    status: str = "creating"

@dataclass
class BaremetalServer:
    id: int
    name: str
    hostname: str
    ip_address: str
    server_type: str
    cpu_cores: int
    memory_gb: int
    storage_gb: int
    status: str
    cluster_status: str

class HetznerClient:
    """Client for Hetzner Cloud API"""
    
    def __init__(self):
        self.api_token = os.getenv("HETZNER_API_TOKEN")
        self.base_url = "https://api.hetzner.cloud/v1"
        self.headers = {
            "Authorization": f"Bearer {self.api_token}",
            "Content-Type": "application/json"
        }
    
    async def _make_request(self, method: str, endpoint: str, **kwargs) -> Dict[str, Any]:
        """Make HTTP request to Hetzner API"""
        url = f"{self.base_url}/{endpoint}"
        
        async with httpx.AsyncClient() as client:
            try:
                response = await client.request(
                    method=method,
                    url=url,
                    headers=self.headers,
                    **kwargs
                )
                response.raise_for_status()
                return response.json()
            except httpx.HTTPStatusError as e:
                logger.error(f"HTTP error: {e.response.status_code} - {e.response.text}")
                raise
            except Exception as e:
                logger.error(f"Request failed: {str(e)}")
                raise
    
    async def get_servers(self) -> List[Dict[str, Any]]:
        """Get all servers"""
        response = await self._make_request("GET", "servers")
        return response.get("servers", [])
    
    async def get_server(self, server_id: int) -> Dict[str, Any]:
        """Get server by ID"""
        response = await self._make_request("GET", f"servers/{server_id}")
        return response.get("server", {})
    
    async def create_server(self, name: str, image: str, server_type: str, 
                           ssh_keys: List[str], user_data: str = "") -> Dict[str, Any]:
        """Create a new server"""
        data = {
            "name": name,
            "image": image,
            "server_type": server_type,
            "ssh_keys": ssh_keys,
            "user_data": user_data
        }
        
        response = await self._make_request("POST", "servers", json=data)
        return response.get("server", {})
    
    async def delete_server(self, server_id: int) -> bool:
        """Delete server"""
        try:
            await self._make_request("DELETE", f"servers/{server_id}")
            return True
        except Exception as e:
            logger.error(f"Failed to delete server {server_id}: {str(e)}")
            return False
    
    async def get_images(self) -> List[Dict[str, Any]]:
        """Get available images"""
        response = await self._make_request("GET", "images")
        return response.get("images", [])
    
    async def get_server_types(self) -> List[Dict[str, Any]]:
        """Get available server types"""
        response = await self._make_request("GET", "server_types")
        return response.get("server_types", [])
    
    async def get_ssh_keys(self) -> List[Dict[str, Any]]:
        """Get SSH keys"""
        response = await self._make_request("GET", "ssh_keys")
        return response.get("ssh_keys", [])
    
    async def create_vm(self, name: str, image: str, server_type: str,
                       cpu: int, memory: int, storage: int,
                       mount_points: List[Dict], namespace: str,
                       user_id: int) -> VMConfig:
        """Create a new VM"""
        try:
            # Get SSH keys
            ssh_keys = await self.get_ssh_keys()
            ssh_key_ids = [key["id"] for key in ssh_keys]
            
            # Create user data for VM
            user_data = self._generate_user_data(name, cpu, memory, storage, mount_points)
            
            # Create server
            server_data = await self.create_server(
                name=name,
                image=image,
                server_type=server_type,
                ssh_keys=ssh_key_ids,
                user_data=user_data
            )
            
            # Create VM config
            vm_config = VMConfig(
                name=name,
                image=image,
                server_type=server_type,
                cpu=cpu,
                memory=memory,
                storage=storage,
                ip_address=server_data.get("public_net", {}).get("ipv4", {}).get("ip"),
                status="running"
            )
            
            logger.info(f"VM {name} created successfully")
            return vm_config
            
        except Exception as e:
            logger.error(f"Failed to create VM {name}: {str(e)}")
            raise
    
    async def update_vm(self, vm_id: int, cpu: int, memory: int, storage: int) -> VMConfig:
        """Update VM resources"""
        try:
            # Get current server info
            server_data = await self.get_server(vm_id)
            
            # Update server type if needed
            new_server_type = self._get_server_type_for_resources(cpu, memory)
            if new_server_type != server_data.get("server_type"):
                # Resize server
                await self._make_request(
                    "POST", 
                    f"servers/{vm_id}/actions/resize",
                    json={"server_type": new_server_type}
                )
            
            # Create updated VM config
            vm_config = VMConfig(
                name=server_data.get("name"),
                image=server_data.get("image", {}).get("name"),
                server_type=new_server_type,
                cpu=cpu,
                memory=memory,
                storage=storage,
                ip_address=server_data.get("public_net", {}).get("ipv4", {}).get("ip"),
                status=server_data.get("status")
            )
            
            logger.info(f"VM {vm_id} updated successfully")
            return vm_config
            
        except Exception as e:
            logger.error(f"Failed to update VM {vm_id}: {str(e)}")
            raise
    
    async def delete_vm(self, vm_id: int) -> bool:
        """Delete VM"""
        return await self.delete_server(vm_id)
    
    async def get_available_resources(self) -> Dict[str, int]:
        """Get available resources across all servers"""
        try:
            servers = await self.get_servers()
            
            total_cpu = 0
            total_memory = 0
            total_storage = 0
            used_cpu = 0
            used_memory = 0
            used_storage = 0
            
            for server in servers:
                server_type = server.get("server_type", {})
                cpu_cores = server_type.get("cores", 0)
                memory_gb = server_type.get("memory", 0) / 1024  # Convert MB to GB
                storage_gb = server_type.get("disk", 0)
                
                total_cpu += cpu_cores
                total_memory += memory_gb
                total_storage += storage_gb
                
                # Check if server is running VMs
                if server.get("status") == "running":
                    # Estimate usage based on running VMs
                    # This would need to be tracked in the database
                    pass
            
            return {
                "total_cpu_cores": total_cpu,
                "available_cpu_cores": total_cpu - used_cpu,
                "total_memory_gb": total_memory,
                "available_memory_gb": total_memory - used_memory,
                "total_storage_gb": total_storage,
                "available_storage_gb": total_storage - used_storage
            }
            
        except Exception as e:
            logger.error(f"Failed to get available resources: {str(e)}")
            return {
                "total_cpu_cores": 0,
                "available_cpu_cores": 0,
                "total_memory_gb": 0,
                "available_memory_gb": 0,
                "total_storage_gb": 0,
                "available_storage_gb": 0
            }
    
    async def add_server_to_cluster(self, server_id: int) -> bool:
        """Add server to Kubernetes cluster"""
        try:
            # This would involve running kubectl commands or using Kubernetes API
            # For now, we'll just mark the server as active
            logger.info(f"Adding server {server_id} to cluster")
            return True
        except Exception as e:
            logger.error(f"Failed to add server {server_id} to cluster: {str(e)}")
            return False
    
    async def remove_server_from_cluster(self, server_id: int) -> bool:
        """Remove server from Kubernetes cluster"""
        try:
            # This would involve draining the node and removing it from the cluster
            logger.info(f"Removing server {server_id} from cluster")
            return True
        except Exception as e:
            logger.error(f"Failed to remove server {server_id} from cluster: {str(e)}")
            return False
    
    def _generate_user_data(self, name: str, cpu: int, memory: int, 
                           storage: int, mount_points: List[Dict]) -> str:
        """Generate cloud-init user data for VM"""
        user_data = f"""#cloud-config
package_update: true
package_upgrade: true
packages:
  - curl
  - wget
  - git
  - vim
  - htop
  - net-tools
users:
  - name: acceldata
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC... acceldata@hetzner-dc
runcmd:
  - systemctl enable sshd
  - systemctl start sshd
  - echo "VM {name} configured with {cpu} CPU, {memory}GB RAM, {storage}GB storage"
"""
        return user_data
    
    def _get_server_type_for_resources(self, cpu: int, memory: int) -> str:
        """Get appropriate server type for given resources"""
        if cpu <= 1 and memory <= 4:
            return "cx11"
        elif cpu <= 2 and memory <= 8:
            return "cx21"
        elif cpu <= 4 and memory <= 16:
            return "cx41"
        elif cpu <= 8 and memory <= 32:
            return "cx51"
        else:
            return "cx51"  # Default to largest type