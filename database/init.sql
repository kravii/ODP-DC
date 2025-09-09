-- Database initialization script for Data Center Management System

-- Create extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Users table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL CHECK (role IN ('admin', 'user')),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Baremetal servers table
CREATE TABLE baremetals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    hostname VARCHAR(100) UNIQUE NOT NULL,
    ip_address INET NOT NULL,
    cpu_cores INTEGER NOT NULL,
    memory_gb INTEGER NOT NULL,
    storage_gb INTEGER NOT NULL,
    iops INTEGER DEFAULT 0,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'maintenance', 'failed')),
    last_health_check TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- VM images table
CREATE TABLE vm_images (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    os_type VARCHAR(50) NOT NULL,
    version VARCHAR(50) NOT NULL,
    image_url TEXT NOT NULL,
    min_cpu INTEGER DEFAULT 1,
    min_memory INTEGER DEFAULT 1024,
    min_storage INTEGER DEFAULT 20,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- VMs table
CREATE TABLE vms (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    hostname VARCHAR(100) UNIQUE NOT NULL,
    ip_address INET,
    baremetal_id UUID REFERENCES baremetals(id) ON DELETE SET NULL,
    image_id UUID REFERENCES vm_images(id),
    cpu_cores INTEGER NOT NULL,
    memory_mb INTEGER NOT NULL,
    status VARCHAR(20) DEFAULT 'creating' CHECK (status IN ('creating', 'running', 'stopped', 'failed', 'deleting')),
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- VM storage mounts table
CREATE TABLE vm_storage_mounts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    vm_id UUID REFERENCES vms(id) ON DELETE CASCADE,
    mount_point VARCHAR(255) NOT NULL,
    storage_gb INTEGER NOT NULL,
    storage_type VARCHAR(20) DEFAULT 'standard' CHECK (storage_type IN ('standard', 'ssd', 'nvme')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Resource pool table (aggregated resources)
CREATE TABLE resource_pool (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    total_cpu_cores INTEGER DEFAULT 0,
    total_memory_gb INTEGER DEFAULT 0,
    total_storage_gb INTEGER DEFAULT 0,
    total_iops INTEGER DEFAULT 0,
    available_cpu_cores INTEGER DEFAULT 0,
    available_memory_gb INTEGER DEFAULT 0,
    available_storage_gb INTEGER DEFAULT 0,
    available_iops INTEGER DEFAULT 0,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Monitoring metrics table
CREATE TABLE monitoring_metrics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    resource_type VARCHAR(20) NOT NULL CHECK (resource_type IN ('baremetal', 'vm')),
    resource_id UUID NOT NULL,
    metric_name VARCHAR(50) NOT NULL,
    metric_value DECIMAL(10,4) NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Alerts table
CREATE TABLE alerts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    resource_type VARCHAR(20) NOT NULL CHECK (resource_type IN ('baremetal', 'vm')),
    resource_id UUID NOT NULL,
    alert_type VARCHAR(50) NOT NULL,
    severity VARCHAR(20) NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    message TEXT NOT NULL,
    is_resolved BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP WITH TIME ZONE
);

-- Notifications table
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    alert_id UUID REFERENCES alerts(id) ON DELETE CASCADE,
    channel VARCHAR(20) NOT NULL CHECK (channel IN ('slack', 'jira', 'email')),
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'failed')),
    sent_at TIMESTAMP WITH TIME ZONE,
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- SSH keys table
CREATE TABLE ssh_keys (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    public_key TEXT NOT NULL,
    private_key TEXT,
    is_default BOOLEAN DEFAULT FALSE,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better performance
CREATE INDEX idx_baremetals_status ON baremetals(status);
CREATE INDEX idx_vms_status ON vms(status);
CREATE INDEX idx_vms_baremetal_id ON vms(baremetal_id);
CREATE INDEX idx_monitoring_metrics_resource ON monitoring_metrics(resource_type, resource_id);
CREATE INDEX idx_monitoring_metrics_timestamp ON monitoring_metrics(timestamp);
CREATE INDEX idx_alerts_unresolved ON alerts(is_resolved) WHERE is_resolved = FALSE;

-- Create triggers for updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_baremetals_updated_at BEFORE UPDATE ON baremetals
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_vms_updated_at BEFORE UPDATE ON vms
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

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