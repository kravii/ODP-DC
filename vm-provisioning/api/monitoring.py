"""
Monitoring service for VMs and baremetal servers
"""

import asyncio
import httpx
from typing import Dict, List, Any, Optional
from datetime import datetime, timedelta
import logging
import os

logger = logging.getLogger(__name__)

class MonitoringService:
    """Service for monitoring VMs and baremetal servers"""
    
    def __init__(self):
        self.prometheus_url = os.getenv("PROMETHEUS_URL", "http://prometheus:9090")
        self.grafana_url = os.getenv("GRAFANA_URL", "http://grafana:3000")
        self.monitoring_interval = int(os.getenv("MONITORING_INTERVAL", "30"))
        self.monitoring_tasks = {}
    
    async def initialize(self):
        """Initialize monitoring service"""
        logger.info("Initializing monitoring service")
        # Start background monitoring tasks
        asyncio.create_task(self._monitor_baremetals())
        asyncio.create_task(self._monitor_vms())
    
    async def cleanup(self):
        """Cleanup monitoring service"""
        logger.info("Cleaning up monitoring service")
        # Cancel all monitoring tasks
        for task in self.monitoring_tasks.values():
            task.cancel()
        self.monitoring_tasks.clear()
    
    async def _monitor_baremetals(self):
        """Monitor baremetal servers"""
        while True:
            try:
                await self._collect_baremetal_metrics()
                await asyncio.sleep(self.monitoring_interval)
            except Exception as e:
                logger.error(f"Error monitoring baremetals: {str(e)}")
                await asyncio.sleep(60)  # Wait longer on error
    
    async def _monitor_vms(self):
        """Monitor VMs"""
        while True:
            try:
                await self._collect_vm_metrics()
                await asyncio.sleep(self.monitoring_interval)
            except Exception as e:
                logger.error(f"Error monitoring VMs: {str(e)}")
                await asyncio.sleep(60)  # Wait longer on error
    
    async def _collect_baremetal_metrics(self):
        """Collect metrics from baremetal servers"""
        try:
            # Query Prometheus for baremetal metrics
            queries = {
                "cpu_usage": "100 - (avg by (instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
                "memory_usage": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100",
                "storage_usage": "100 - ((node_filesystem_avail_bytes * 100) / node_filesystem_size_bytes)",
                "network_in": "irate(node_network_receive_bytes_total[5m])",
                "network_out": "irate(node_network_transmit_bytes_total[5m])",
                "disk_read": "irate(node_disk_read_bytes_total[5m])",
                "disk_write": "irate(node_disk_written_bytes_total[5m])"
            }
            
            metrics = {}
            async with httpx.AsyncClient() as client:
                for metric_name, query in queries.items():
                    try:
                        response = await client.get(
                            f"{self.prometheus_url}/api/v1/query",
                            params={"query": query}
                        )
                        if response.status_code == 200:
                            data = response.json()
                            metrics[metric_name] = data.get("data", {}).get("result", [])
                    except Exception as e:
                        logger.error(f"Failed to query {metric_name}: {str(e)}")
            
            # Process and store metrics
            await self._process_baremetal_metrics(metrics)
            
        except Exception as e:
            logger.error(f"Failed to collect baremetal metrics: {str(e)}")
    
    async def _collect_vm_metrics(self):
        """Collect metrics from VMs"""
        try:
            # Query Prometheus for VM metrics
            queries = {
                "cpu_usage": "rate(container_cpu_usage_seconds_total[5m]) * 100",
                "memory_usage": "container_memory_usage_bytes / container_spec_memory_limit_bytes * 100",
                "storage_usage": "container_fs_usage_bytes / container_fs_limit_bytes * 100",
                "network_in": "rate(container_network_receive_bytes_total[5m])",
                "network_out": "rate(container_network_transmit_bytes_total[5m])"
            }
            
            metrics = {}
            async with httpx.AsyncClient() as client:
                for metric_name, query in queries.items():
                    try:
                        response = await client.get(
                            f"{self.prometheus_url}/api/v1/query",
                            params={"query": query}
                        )
                        if response.status_code == 200:
                            data = response.json()
                            metrics[metric_name] = data.get("data", {}).get("result", [])
                    except Exception as e:
                        logger.error(f"Failed to query {metric_name}: {str(e)}")
            
            # Process and store metrics
            await self._process_vm_metrics(metrics)
            
        except Exception as e:
            logger.error(f"Failed to collect VM metrics: {str(e)}")
    
    async def _process_baremetal_metrics(self, metrics: Dict[str, List]):
        """Process and store baremetal metrics"""
        # This would store metrics in the database
        # For now, we'll just log them
        logger.debug(f"Processed baremetal metrics: {len(metrics)} metric types")
    
    async def _process_vm_metrics(self, metrics: Dict[str, List]):
        """Process and store VM metrics"""
        # This would store metrics in the database
        # For now, we'll just log them
        logger.debug(f"Processed VM metrics: {len(metrics)} metric types")
    
    async def start_vm_monitoring(self, vm_id: int):
        """Start monitoring a specific VM"""
        logger.info(f"Starting monitoring for VM {vm_id}")
        # This would start monitoring for a specific VM
        # Could involve creating Prometheus targets or other monitoring setup
    
    async def stop_vm_monitoring(self, vm_id: int):
        """Stop monitoring a specific VM"""
        logger.info(f"Stopping monitoring for VM {vm_id}")
        # This would stop monitoring for a specific VM
    
    async def get_dashboard_data(self) -> Dict[str, Any]:
        """Get dashboard data for monitoring"""
        try:
            # Query Prometheus for dashboard metrics
            queries = {
                "total_vms": "count(up{job=\"vm-provisioner\"})",
                "running_vms": "count(up{job=\"vm-provisioner\",status=\"running\"})",
                "total_baremetals": "count(up{job=\"node-exporter\"})",
                "active_baremetals": "count(up{job=\"node-exporter\",status=\"active\"})",
                "total_cpu_cores": "sum(machine_cpu_cores)",
                "used_cpu_cores": "sum(rate(container_cpu_usage_seconds_total[5m]))",
                "total_memory_gb": "sum(machine_memory_bytes) / 1024 / 1024 / 1024",
                "used_memory_gb": "sum(container_memory_usage_bytes) / 1024 / 1024 / 1024",
                "total_storage_gb": "sum(node_filesystem_size_bytes) / 1024 / 1024 / 1024",
                "used_storage_gb": "sum(node_filesystem_size_bytes - node_filesystem_avail_bytes) / 1024 / 1024 / 1024"
            }
            
            dashboard_data = {}
            async with httpx.AsyncClient() as client:
                for key, query in queries.items():
                    try:
                        response = await client.get(
                            f"{self.prometheus_url}/api/v1/query",
                            params={"query": query}
                        )
                        if response.status_code == 200:
                            data = response.json()
                            result = data.get("data", {}).get("result", [])
                            if result:
                                dashboard_data[key] = float(result[0].get("value", [1, "0"])[1])
                            else:
                                dashboard_data[key] = 0
                    except Exception as e:
                        logger.error(f"Failed to query {key}: {str(e)}")
                        dashboard_data[key] = 0
            
            # Add recent alerts
            dashboard_data["recent_alerts"] = await self._get_recent_alerts()
            
            return dashboard_data
            
        except Exception as e:
            logger.error(f"Failed to get dashboard data: {str(e)}")
            return {
                "total_vms": 0,
                "running_vms": 0,
                "total_baremetals": 0,
                "active_baremetals": 0,
                "total_cpu_cores": 0,
                "used_cpu_cores": 0,
                "total_memory_gb": 0,
                "used_memory_gb": 0,
                "total_storage_gb": 0,
                "used_storage_gb": 0,
                "recent_alerts": []
            }
    
    async def get_vm_monitoring_data(self, vm_id: int) -> Dict[str, Any]:
        """Get monitoring data for a specific VM"""
        try:
            # Query Prometheus for VM-specific metrics
            queries = {
                "cpu_usage": f"rate(container_cpu_usage_seconds_total{{container_label_vm_id=\"{vm_id}\"}}[5m]) * 100",
                "memory_usage": f"container_memory_usage_bytes{{container_label_vm_id=\"{vm_id}\"}} / container_spec_memory_limit_bytes{{container_label_vm_id=\"{vm_id}\"}} * 100",
                "storage_usage": f"container_fs_usage_bytes{{container_label_vm_id=\"{vm_id}\"}} / container_fs_limit_bytes{{container_label_vm_id=\"{vm_id}\"}} * 100",
                "network_in": f"rate(container_network_receive_bytes_total{{container_label_vm_id=\"{vm_id}\"}}[5m])",
                "network_out": f"rate(container_network_transmit_bytes_total{{container_label_vm_id=\"{vm_id}\"}}[5m])",
                "uptime": f"time() - container_start_time_seconds{{container_label_vm_id=\"{vm_id}\"}}"
            }
            
            vm_data = {"vm_id": vm_id}
            async with httpx.AsyncClient() as client:
                for key, query in queries.items():
                    try:
                        response = await client.get(
                            f"{self.prometheus_url}/api/v1/query",
                            params={"query": query}
                        )
                        if response.status_code == 200:
                            data = response.json()
                            result = data.get("data", {}).get("result", [])
                            if result:
                                vm_data[key] = float(result[0].get("value", [1, "0"])[1])
                            else:
                                vm_data[key] = 0
                    except Exception as e:
                        logger.error(f"Failed to query {key} for VM {vm_id}: {str(e)}")
                        vm_data[key] = 0
            
            vm_data["last_updated"] = datetime.utcnow()
            return vm_data
            
        except Exception as e:
            logger.error(f"Failed to get VM monitoring data for {vm_id}: {str(e)}")
            return {"vm_id": vm_id, "error": str(e)}
    
    async def get_baremetal_monitoring_data(self, server_id: int) -> Dict[str, Any]:
        """Get monitoring data for a specific baremetal server"""
        try:
            # Query Prometheus for server-specific metrics
            queries = {
                "cpu_usage": f"100 - (avg by (instance) (irate(node_cpu_seconds_total{{instance=~\".*{server_id}.*\"}}[5m])) * 100)",
                "memory_usage": f"(1 - (node_memory_MemAvailable_bytes{{instance=~\".*{server_id}.*\"}} / node_memory_MemTotal_bytes{{instance=~\".*{server_id}.*\"}})) * 100",
                "storage_usage": f"100 - ((node_filesystem_avail_bytes{{instance=~\".*{server_id}.*\"}} * 100) / node_filesystem_size_bytes{{instance=~\".*{server_id}.*\"}})",
                "temperature": f"node_hwmon_temp_celsius{{instance=~\".*{server_id}.*\"}}",
                "network_in": f"irate(node_network_receive_bytes_total{{instance=~\".*{server_id}.*\"}}[5m])",
                "network_out": f"irate(node_network_transmit_bytes_total{{instance=~\".*{server_id}.*\"}}[5m])",
                "uptime": f"node_boot_time_seconds{{instance=~\".*{server_id}.*\"}}"
            }
            
            server_data = {"server_id": server_id}
            async with httpx.AsyncClient() as client:
                for key, query in queries.items():
                    try:
                        response = await client.get(
                            f"{self.prometheus_url}/api/v1/query",
                            params={"query": query}
                        )
                        if response.status_code == 200:
                            data = response.json()
                            result = data.get("data", {}).get("result", [])
                            if result:
                                server_data[key] = float(result[0].get("value", [1, "0"])[1])
                            else:
                                server_data[key] = 0
                    except Exception as e:
                        logger.error(f"Failed to query {key} for server {server_id}: {str(e)}")
                        server_data[key] = 0
            
            server_data["last_updated"] = datetime.utcnow()
            return server_data
            
        except Exception as e:
            logger.error(f"Failed to get baremetal monitoring data for {server_id}: {str(e)}")
            return {"server_id": server_id, "error": str(e)}
    
    async def _get_recent_alerts(self) -> List[Dict[str, Any]]:
        """Get recent alerts from AlertManager"""
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(f"{self.prometheus_url}/api/v1/alerts")
                if response.status_code == 200:
                    data = response.json()
                    alerts = data.get("data", {}).get("alerts", [])
                    
                    # Filter recent alerts (last 24 hours)
                    recent_alerts = []
                    cutoff_time = datetime.utcnow() - timedelta(hours=24)
                    
                    for alert in alerts:
                        alert_time = datetime.fromisoformat(alert.get("activeAt", "").replace("Z", "+00:00"))
                        if alert_time > cutoff_time:
                            recent_alerts.append({
                                "name": alert.get("labels", {}).get("alertname"),
                                "severity": alert.get("labels", {}).get("severity"),
                                "status": alert.get("state"),
                                "description": alert.get("annotations", {}).get("description"),
                                "timestamp": alert_time.isoformat()
                            })
                    
                    return recent_alerts[:10]  # Return last 10 alerts
                else:
                    return []
        except Exception as e:
            logger.error(f"Failed to get recent alerts: {str(e)}")
            return []