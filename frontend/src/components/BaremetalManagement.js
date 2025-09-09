import React, { useState, useEffect } from 'react';
import { 
  Table, 
  Button, 
  Modal, 
  Form, 
  Input, 
  InputNumber, 
  Select, 
  Space, 
  Popconfirm, 
  message, 
  Card, 
  Row, 
  Col, 
  Statistic,
  Tag,
  Tooltip,
  Divider
} from 'antd';
import { 
  PlusOutlined, 
  EditOutlined, 
  DeleteOutlined, 
  ReloadOutlined,
  CheckCircleOutlined,
  ExclamationCircleOutlined,
  CloseCircleOutlined
} from '@ant-design/icons';
import { apiService } from '../services/api';

const { Option } = Select;

const BaremetalManagement = () => {
  const [baremetals, setBaremetals] = useState([]);
  const [resourcePool, setResourcePool] = useState(null);
  const [loading, setLoading] = useState(false);
  const [modalVisible, setModalVisible] = useState(false);
  const [editingBaremetal, setEditingBaremetal] = useState(null);
  const [form] = Form.useForm();

  useEffect(() => {
    fetchBaremetals();
    fetchResourcePool();
  }, []);

  const fetchBaremetals = async () => {
    setLoading(true);
    try {
      const response = await apiService.baremetals.getAll();
      setBaremetals(response.data);
    } catch (error) {
      message.error('Failed to fetch baremetal servers');
    } finally {
      setLoading(false);
    }
  };

  const fetchResourcePool = async () => {
    try {
      const response = await apiService.baremetals.getResourcePool();
      setResourcePool(response.data);
    } catch (error) {
      console.error('Failed to fetch resource pool:', error);
    }
  };

  const handleAdd = () => {
    setEditingBaremetal(null);
    form.resetFields();
    setModalVisible(true);
  };

  const handleEdit = (record) => {
    setEditingBaremetal(record);
    form.setFieldsValue({
      hostname: record.hostname,
      ip_address: record.ip_address,
      os_type: record.os_type,
      cpu_cores: record.cpu_cores,
      memory_gb: record.memory_gb,
      status: record.status,
      storage_mounts: record.storage_mounts || [],
    });
    setModalVisible(true);
  };

  const handleDelete = async (id) => {
    try {
      await apiService.baremetals.delete(id);
      message.success('Baremetal server deleted successfully');
      fetchBaremetals();
      fetchResourcePool();
    } catch (error) {
      message.error('Failed to delete baremetal server');
    }
  };

  const handleSubmit = async (values) => {
    try {
      if (editingBaremetal) {
        await apiService.baremetals.update(editingBaremetal.id, values);
        message.success('Baremetal server updated successfully');
      } else {
        await apiService.baremetals.create(values);
        message.success('Baremetal server added successfully');
      }
      setModalVisible(false);
      fetchBaremetals();
      fetchResourcePool();
    } catch (error) {
      message.error(error.response?.data?.detail || 'Operation failed');
    }
  };

  const getStatusColor = (status) => {
    switch (status) {
      case 'active': return 'green';
      case 'inactive': return 'orange';
      case 'maintenance': return 'blue';
      case 'failed': return 'red';
      default: return 'default';
    }
  };

  const getStatusIcon = (status) => {
    switch (status) {
      case 'active': return <CheckCircleOutlined />;
      case 'inactive': return <ExclamationCircleOutlined />;
      case 'maintenance': return <ExclamationCircleOutlined />;
      case 'failed': return <CloseCircleOutlined />;
      default: return <ExclamationCircleOutlined />;
    }
  };

  const columns = [
    {
      title: 'Hostname',
      dataIndex: 'hostname',
      key: 'hostname',
      sorter: (a, b) => a.hostname.localeCompare(b.hostname),
    },
    {
      title: 'IP Address',
      dataIndex: 'ip_address',
      key: 'ip_address',
    },
    {
      title: 'OS Type',
      dataIndex: 'os_type',
      key: 'os_type',
      render: (osType) => (
        <Tag color="blue">{osType.toUpperCase()}</Tag>
      ),
      filters: [
        { text: 'RHEL 8', value: 'rhel8' },
        { text: 'Rocky Linux 9', value: 'rocky9' },
        { text: 'Ubuntu 20', value: 'ubuntu20' },
        { text: 'Ubuntu 22', value: 'ubuntu22' },
      ],
      onFilter: (value, record) => record.os_type === value,
    },
    {
      title: 'Status',
      dataIndex: 'status',
      key: 'status',
      render: (status) => (
        <Tag color={getStatusColor(status)} icon={getStatusIcon(status)}>
          {status.toUpperCase()}
        </Tag>
      ),
      filters: [
        { text: 'Active', value: 'active' },
        { text: 'Inactive', value: 'inactive' },
        { text: 'Maintenance', value: 'maintenance' },
        { text: 'Failed', value: 'failed' },
      ],
      onFilter: (value, record) => record.status === value,
    },
    {
      title: 'CPU Cores',
      dataIndex: 'cpu_cores',
      key: 'cpu_cores',
      sorter: (a, b) => a.cpu_cores - b.cpu_cores,
    },
    {
      title: 'Memory (GB)',
      dataIndex: 'memory_gb',
      key: 'memory_gb',
      sorter: (a, b) => a.memory_gb - b.memory_gb,
    },
    {
      title: 'Storage Mounts',
      dataIndex: 'storage_mounts',
      key: 'storage_mounts',
      render: (mounts) => (
        <div>
          {mounts?.map((mount, index) => (
            <div key={index} style={{ fontSize: '12px' }}>
              {mount.mount_point}: {mount.storage_gb}GB ({mount.storage_type})
            </div>
          ))}
        </div>
      ),
    },
    {
      title: 'Total Storage (GB)',
      key: 'total_storage',
      render: (_, record) => {
        const total = record.storage_mounts?.reduce((sum, mount) => sum + mount.storage_gb, 0) || 0;
        return total;
      },
      sorter: (a, b) => {
        const aTotal = a.storage_mounts?.reduce((sum, mount) => sum + mount.storage_gb, 0) || 0;
        const bTotal = b.storage_mounts?.reduce((sum, mount) => sum + mount.storage_gb, 0) || 0;
        return aTotal - bTotal;
      },
    },
    {
      title: 'Last Health Check',
      dataIndex: 'last_health_check',
      key: 'last_health_check',
      render: (time) => time ? new Date(time).toLocaleString() : 'Never',
    },
    {
      title: 'Actions',
      key: 'actions',
      render: (_, record) => (
        <Space>
          <Tooltip title="Edit">
            <Button 
              type="text" 
              icon={<EditOutlined />} 
              onClick={() => handleEdit(record)}
            />
          </Tooltip>
          <Popconfirm
            title="Are you sure you want to delete this baremetal server?"
            onConfirm={() => handleDelete(record.id)}
            okText="Yes"
            cancelText="No"
          >
            <Tooltip title="Delete">
              <Button 
                type="text" 
                danger 
                icon={<DeleteOutlined />}
              />
            </Tooltip>
          </Popconfirm>
        </Space>
      ),
    },
  ];

  return (
    <div>
      <Row gutter={[16, 16]} style={{ marginBottom: 16 }}>
        <Col xs={24} sm={6}>
          <Card>
            <Statistic
              title="Total Servers"
              value={baremetals.length}
              prefix={<CheckCircleOutlined />}
            />
          </Card>
        </Col>
        <Col xs={24} sm={6}>
          <Card>
            <Statistic
              title="Active Servers"
              value={baremetals.filter(b => b.status === 'active').length}
              valueStyle={{ color: '#3f8600' }}
            />
          </Card>
        </Col>
        <Col xs={24} sm={6}>
          <Card>
            <Statistic
              title="Total CPU Cores"
              value={resourcePool?.total_cpu_cores || 0}
            />
          </Card>
        </Col>
        <Col xs={24} sm={6}>
          <Card>
            <Statistic
              title="Total Memory (GB)"
              value={resourcePool?.total_memory_gb || 0}
            />
          </Card>
        </Col>
      </Row>

      <Card
        title="Baremetal Servers"
        extra={
          <Space>
            <Button 
              icon={<ReloadOutlined />} 
              onClick={fetchBaremetals}
              loading={loading}
            >
              Refresh
            </Button>
            <Button 
              type="primary" 
              icon={<PlusOutlined />} 
              onClick={handleAdd}
            >
              Add Server
            </Button>
          </Space>
        }
      >
        <Table
          columns={columns}
          dataSource={baremetals}
          rowKey="id"
          loading={loading}
          pagination={{
            pageSize: 10,
            showSizeChanger: true,
            showQuickJumper: true,
            showTotal: (total, range) => 
              `${range[0]}-${range[1]} of ${total} servers`,
          }}
        />
      </Card>

      <Modal
        title={editingBaremetal ? 'Edit Baremetal Server' : 'Add Baremetal Server'}
        open={modalVisible}
        onCancel={() => setModalVisible(false)}
        footer={null}
        width={600}
      >
        <Form
          form={form}
          layout="vertical"
          onFinish={handleSubmit}
        >
          <Row gutter={16}>
            <Col span={12}>
              <Form.Item
                name="hostname"
                label="Hostname"
                rules={[{ required: true, message: 'Please input hostname!' }]}
              >
                <Input placeholder="server-01" />
              </Form.Item>
            </Col>
            <Col span={12}>
              <Form.Item
                name="ip_address"
                label="IP Address"
                rules={[
                  { required: true, message: 'Please input IP address!' },
                  { pattern: /^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$/, message: 'Please input valid IP address!' }
                ]}
              >
                <Input placeholder="192.168.1.100" />
              </Form.Item>
            </Col>
          </Row>

          <Form.Item
            name="os_type"
            label="Operating System"
            rules={[{ required: true, message: 'Please select OS type!' }]}
          >
            <Select placeholder="Select OS type">
              <Option value="rhel8">RHEL 8</Option>
              <Option value="rocky9">Rocky Linux 9</Option>
              <Option value="ubuntu20">Ubuntu 20.04</Option>
              <Option value="ubuntu22">Ubuntu 22.04</Option>
            </Select>
          </Form.Item>

          <Row gutter={16}>
            <Col span={12}>
              <Form.Item
                name="cpu_cores"
                label="CPU Cores"
                rules={[{ required: true, message: 'Please input CPU cores!' }]}
              >
                <InputNumber min={1} max={128} style={{ width: '100%' }} />
              </Form.Item>
            </Col>
            <Col span={12}>
              <Form.Item
                name="memory_gb"
                label="Memory (GB)"
                rules={[{ required: true, message: 'Please input memory!' }]}
              >
                <InputNumber min={1} max={1024} style={{ width: '100%' }} />
              </Form.Item>
            </Col>
          </Row>

          <Divider>Storage Configuration</Divider>

          <Form.Item
            name="storage_mounts"
            label="Storage Mounts"
            initialValue={[{ mount_point: '/', storage_gb: 100, storage_type: 'standard', iops: 0 }]}
          >
            <Form.List name="storage_mounts">
              {(fields, { add, remove }) => (
                <>
                  {fields.map(({ key, name, ...restField }) => (
                    <Space key={key} style={{ display: 'flex', marginBottom: 8 }} align="baseline">
                      <Form.Item
                        {...restField}
                        name={[name, 'mount_point']}
                        rules={[{ required: true, message: 'Missing mount point' }]}
                        style={{ width: 120 }}
                      >
                        <Input placeholder="Mount point" />
                      </Form.Item>
                      <Form.Item
                        {...restField}
                        name={[name, 'storage_gb']}
                        rules={[{ required: true, message: 'Missing storage size' }]}
                        style={{ width: 100 }}
                      >
                        <InputNumber placeholder="Size (GB)" min={1} max={10000} />
                      </Form.Item>
                      <Form.Item
                        {...restField}
                        name={[name, 'storage_type']}
                        rules={[{ required: true, message: 'Missing storage type' }]}
                        style={{ width: 100 }}
                      >
                        <Select placeholder="Type">
                          <Option value="standard">Standard</Option>
                          <Option value="ssd">SSD</Option>
                          <Option value="nvme">NVMe</Option>
                        </Select>
                      </Form.Item>
                      <Form.Item
                        {...restField}
                        name={[name, 'iops']}
                        style={{ width: 80 }}
                      >
                        <InputNumber placeholder="IOPS" min={0} max={100000} />
                      </Form.Item>
                      <Button onClick={() => remove(name)}>Remove</Button>
                    </Space>
                  ))}
                  <Form.Item>
                    <Button type="dashed" onClick={() => add()} block>
                      Add Storage Mount
                    </Button>
                  </Form.Item>
                </>
              )}
            </Form.List>
          </Form.Item>

          {editingBaremetal && (
            <Form.Item
              name="status"
              label="Status"
            >
              <Select>
                <Option value="active">Active</Option>
                <Option value="inactive">Inactive</Option>
                <Option value="maintenance">Maintenance</Option>
                <Option value="failed">Failed</Option>
              </Select>
            </Form.Item>
          )}

          <Form.Item style={{ marginBottom: 0, textAlign: 'right' }}>
            <Space>
              <Button onClick={() => setModalVisible(false)}>
                Cancel
              </Button>
              <Button type="primary" htmlType="submit">
                {editingBaremetal ? 'Update' : 'Add'}
              </Button>
            </Space>
          </Form.Item>
        </Form>
      </Modal>
    </div>
  );
};

export default BaremetalManagement;