-- Database initialization script for Data Center Management System (MySQL)

-- Create database if not exists
CREATE DATABASE IF NOT EXISTS datacenter;
USE datacenter;

-- Users table
CREATE TABLE users (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role ENUM('admin', 'user') NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Baremetal servers table
CREATE TABLE baremetals (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    hostname VARCHAR(100) UNIQUE NOT NULL,
    ip_address VARCHAR(45) NOT NULL,
    os_type ENUM('rhel8', 'rocky9', 'ubuntu20', 'ubuntu22') NOT NULL,
    cpu_cores INT NOT NULL,
    memory_gb INT NOT NULL,
    status ENUM('active', 'inactive', 'maintenance', 'failed') DEFAULT 'active',
    last_health_check TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Baremetal storage mounts table
CREATE TABLE baremetal_storage_mounts (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    baremetal_id CHAR(36) NOT NULL,
    mount_point VARCHAR(255) NOT NULL,
    storage_gb INT NOT NULL,
    storage_type ENUM('standard', 'ssd', 'nvme') DEFAULT 'standard',
    iops INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (baremetal_id) REFERENCES baremetals(id) ON DELETE CASCADE
);

-- VM images table
CREATE TABLE vm_images (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    name VARCHAR(100) NOT NULL,
    os_type VARCHAR(50) NOT NULL,
    version VARCHAR(50) NOT NULL,
    image_url TEXT NOT NULL,
    min_cpu INT DEFAULT 1,
    min_memory INT DEFAULT 1024,
    min_storage INT DEFAULT 20,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- VMs table
CREATE TABLE vms (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    hostname VARCHAR(100) UNIQUE NOT NULL,
    ip_address VARCHAR(45) NULL,
    baremetal_id CHAR(36) NULL,
    image_id CHAR(36) NOT NULL,
    cpu_cores INT NOT NULL,
    memory_mb INT NOT NULL,
    status ENUM('creating', 'running', 'stopped', 'failed', 'deleting') DEFAULT 'creating',
    created_by CHAR(36) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (baremetal_id) REFERENCES baremetals(id) ON DELETE SET NULL,
    FOREIGN KEY (image_id) REFERENCES vm_images(id),
    FOREIGN KEY (created_by) REFERENCES users(id)
);

-- VM storage mounts table
CREATE TABLE vm_storage_mounts (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    vm_id CHAR(36) NOT NULL,
    mount_point VARCHAR(255) NOT NULL,
    storage_gb INT NOT NULL,
    storage_type ENUM('standard', 'ssd', 'nvme') DEFAULT 'standard',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (vm_id) REFERENCES vms(id) ON DELETE CASCADE
);

-- Resource pool table (aggregated resources)
CREATE TABLE resource_pool (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    total_cpu_cores INT DEFAULT 0,
    total_memory_gb INT DEFAULT 0,
    total_storage_gb INT DEFAULT 0,
    total_iops INT DEFAULT 0,
    available_cpu_cores INT DEFAULT 0,
    available_memory_gb INT DEFAULT 0,
    available_storage_gb INT DEFAULT 0,
    available_iops INT DEFAULT 0,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Monitoring metrics table
CREATE TABLE monitoring_metrics (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    resource_type ENUM('baremetal', 'vm') NOT NULL,
    resource_id CHAR(36) NOT NULL,
    metric_name VARCHAR(50) NOT NULL,
    metric_value DECIMAL(10,4) NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_resource (resource_type, resource_id),
    INDEX idx_timestamp (timestamp)
);

-- Alerts table
CREATE TABLE alerts (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    resource_type ENUM('baremetal', 'vm') NOT NULL,
    resource_id CHAR(36) NOT NULL,
    alert_type VARCHAR(50) NOT NULL,
    severity ENUM('low', 'medium', 'high', 'critical') NOT NULL,
    message TEXT NOT NULL,
    is_resolved BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP NULL,
    INDEX idx_unresolved (is_resolved)
);

-- Notifications table
CREATE TABLE notifications (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    alert_id CHAR(36) NOT NULL,
    channel ENUM('slack', 'jira', 'email') NOT NULL,
    status ENUM('pending', 'sent', 'failed') DEFAULT 'pending',
    sent_at TIMESTAMP NULL,
    error_message TEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (alert_id) REFERENCES alerts(id) ON DELETE CASCADE
);

-- SSH keys table
CREATE TABLE ssh_keys (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    name VARCHAR(100) NOT NULL,
    public_key TEXT NOT NULL,
    private_key TEXT NULL,
    is_default BOOLEAN DEFAULT FALSE,
    created_by CHAR(36) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (created_by) REFERENCES users(id)
);

-- Insert default VM images
INSERT INTO vm_images (name, os_type, version, image_url, min_cpu, min_memory, min_storage) VALUES
('CentOS 7', 'centos', '7', 'https://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.qcow2', 1, 1024, 20),
('RHEL 7', 'rhel', '7', 'https://access.redhat.com/downloads/content/69/ver=/rhel---7/7.9/x86_64/product-software', 1, 1024, 20),
('RHEL 8', 'rhel', '8', 'https://access.redhat.com/downloads/content/479/ver=/rhel---8/8.8/x86_64/product-software', 1, 1024, 20),
('RHEL 9', 'rhel', '9', 'https://access.redhat.com/downloads/content/479/ver=/rhel---9/9.2/x86_64/product-software', 1, 1024, 20),
('Rocky Linux 9', 'rocky', '9', 'https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2', 1, 1024, 20),
('Ubuntu 20.04', 'ubuntu', '20.04', 'https://cloud-images.ubuntu.com/releases/20.04/release/ubuntu-20.04-server-cloudimg-amd64.img', 1, 1024, 20),
('Ubuntu 22.04', 'ubuntu', '22.04', 'https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-amd64.img', 1, 1024, 20),
('Ubuntu 24.04', 'ubuntu', '24.04', 'https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img', 1, 1024, 20),
('Oracle Linux 8.10', 'oel', '8.10', 'https://yum.oracle.com/templates/OracleLinux-EL8/ol8_template.json', 1, 1024, 20);

-- Insert default admin user (password: admin123)
INSERT INTO users (username, email, password_hash, role) VALUES
('admin', 'admin@datacenter.local', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj4J/HS.s8i2', 'admin');

-- Insert initial resource pool
INSERT INTO resource_pool (total_cpu_cores, total_memory_gb, total_storage_gb, total_iops, 
                          available_cpu_cores, available_memory_gb, available_storage_gb, available_iops) 
VALUES (0, 0, 0, 0, 0, 0, 0, 0);