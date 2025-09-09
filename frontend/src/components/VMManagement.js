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
  PlayCircleOutlined,
  PauseCircleOutlined,
  CheckCircleOutlined,
  ExclamationCircleOutlined,
  CloseCircleOutlined
} from '@ant-design/icons';
import { apiService } from '../services/api';

const { Option } = Select;

const VMManagement = () => {
  const [vms, setVms] = useState([]);
  const [images, setImages] = useState([]);
  const [loading, setLoading] = useState(false);
  const [modalVisible, setModalVisible] = useState(false);
  const [editingVM, setEditingVM] = useState(null);
  const [form] = Form.useForm();

  useEffect(() => {
    fetchVMs();
    fetchImages();
  }, []);

  const fetchVMs = async () => {
    setLoading(true);
    try {
      const response = await apiService.vms.getAll();
      setVms(response.data);
    } catch (error) {
      message.error('Failed to fetch virtual machines');
    } finally {
      setLoading(false);
    }
  };

  const fetchImages = async () => {
    try {
      const response = await apiService.vms.getImages();
      setImages(response.data);
    } catch (error) {
      console.error('Failed to fetch VM images:', error);
    }
  };

  const handleAdd = () => {
    setEditingVM(null);
    form.resetFields();
    setModalVisible(true);
  };

  const handleEdit = (record) => {
    setEditingVM(record);
    form.setFieldsValue({
      hostname: record.hostname,
      ip_address: record.ip_address,
      cpu_cores: record.cpu_cores,
      memory_mb: record.memory_mb,
    });
    setModalVisible(true);
  };

  const handleDelete = async (id) => {
    try {
      await apiService.vms.delete(id);
      message.success('Virtual machine deleted successfully');
      fetchVMs();
    } catch (error) {
      message.error('Failed to delete virtual machine');
    }
  };

  const handleStart = async (id) => {
    try {
      await apiService.vms.start(id);
      message.success('Virtual machine started successfully');
      fetchVMs();
    } catch (error) {
      message.error('Failed to start virtual machine');
    }
  };

  const handleStop = async (id) => {
    try {
      await apiService.vms.stop(id);
      message.success('Virtual machine stopped successfully');
      fetchVMs();
    } catch (error) {
      message.error('Failed to stop virtual machine');
    }
  };

  const handleSubmit = async (values) => {
    try {
      if (editingVM) {
        await apiService.vms.update(editingVM.id, values);
        message.success('Virtual machine updated successfully');
      } else {
        await apiService.vms.create(values);
        message.success('Virtual machine created successfully');
      }
      setModalVisible(false);
      fetchVMs();
    } catch (error) {
      message.error(error.response?.data?.detail || 'Operation failed');
    }
  };

  const getStatusColor = (status) => {
    switch (status) {
      case 'running': return 'green';
      case 'stopped': return 'orange';
      case 'creating': return 'blue';
      case 'deleting': return 'purple';
      case 'failed': return 'red';
      default: return 'default';
    }
  };

  const getStatusIcon = (status) => {
    switch (status) {
      case 'running': return <CheckCircleOutlined />;
      case 'stopped': return <PauseCircleOutlined />;
      case 'creating': return <ExclamationCircleOutlined />;
      case 'deleting': return <ExclamationCircleOutlined />;
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
      render: (ip) => ip || 'N/A',
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
        { text: 'Running', value: 'running' },
        { text: 'Stopped', value: 'stopped' },
        { text: 'Creating', value: 'creating' },
        { text: 'Deleting', value: 'deleting' },
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
      title: 'Memory (MB)',
      dataIndex: 'memory_mb',
      key: 'memory_mb',
      sorter: (a, b) => a.memory_mb - b.memory_mb,
    },
    {
      title: 'Created',
      dataIndex: 'created_at',
      key: 'created_at',
      render: (time) => new Date(time).toLocaleString(),
      sorter: (a, b) => new Date(a.created_at) - new Date(b.created_at),
    },
    {
      title: 'Actions',
      key: 'actions',
      render: (_, record) => (
        <Space>
          {record.status === 'stopped' && (
            <Tooltip title="Start">
              <Button 
                type="text" 
                icon={<PlayCircleOutlined />} 
                onClick={() => handleStart(record.id)}
              />
            </Tooltip>
          )}
          {record.status === 'running' && (
            <Tooltip title="Stop">
              <Button 
                type="text" 
                icon={<PauseCircleOutlined />} 
                onClick={() => handleStop(record.id)}
              />
            </Tooltip>
          )}
          <Tooltip title="Edit">
            <Button 
              type="text" 
              icon={<EditOutlined />} 
              onClick={() => handleEdit(record)}
            />
          </Tooltip>
          <Popconfirm
            title="Are you sure you want to delete this virtual machine?"
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
              title="Total VMs"
              value={vms.length}
              prefix={<CheckCircleOutlined />}
            />
          </Card>
        </Col>
        <Col xs={24} sm={6}>
          <Card>
            <Statistic
              title="Running VMs"
              value={vms.filter(v => v.status === 'running').length}
              valueStyle={{ color: '#3f8600' }}
            />
          </Card>
        </Col>
        <Col xs={24} sm={6}>
          <Card>
            <Statistic
              title="Stopped VMs"
              value={vms.filter(v => v.status === 'stopped').length}
              valueStyle={{ color: '#faad14' }}
            />
          </Card>
        </Col>
        <Col xs={24} sm={6}>
          <Card>
            <Statistic
              title="Failed VMs"
              value={vms.filter(v => v.status === 'failed').length}
              valueStyle={{ color: '#ff4d4f' }}
            />
          </Card>
        </Col>
      </Row>

      <Card
        title="Virtual Machines"
        extra={
          <Space>
            <Button 
              icon={<ReloadOutlined />} 
              onClick={fetchVMs}
              loading={loading}
            >
              Refresh
            </Button>
            <Button 
              type="primary" 
              icon={<PlusOutlined />} 
              onClick={handleAdd}
            >
              Launch VM
            </Button>
          </Space>
        }
      >
        <Table
          columns={columns}
          dataSource={vms}
          rowKey="id"
          loading={loading}
          pagination={{
            pageSize: 10,
            showSizeChanger: true,
            showQuickJumper: true,
            showTotal: (total, range) => 
              `${range[0]}-${range[1]} of ${total} VMs`,
          }}
        />
      </Card>

      <Modal
        title={editingVM ? 'Edit Virtual Machine' : 'Launch Virtual Machine'}
        open={modalVisible}
        onCancel={() => setModalVisible(false)}
        footer={null}
        width={800}
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
                <Input placeholder="vm-01" />
              </Form.Item>
            </Col>
            <Col span={12}>
              <Form.Item
                name="ip_address"
                label="IP Address (Optional)"
                rules={[
                  { pattern: /^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$/, message: 'Please input valid IP address!' }
                ]}
              >
                <Input placeholder="192.168.1.101" />
              </Form.Item>
            </Col>
          </Row>

          {!editingVM && (
            <>
              <Form.Item
                name="image_id"
                label="Operating System"
                rules={[{ required: true, message: 'Please select an OS image!' }]}
              >
                <Select 
                  placeholder="Select OS image"
                  showSearch
                  filterOption={(input, option) =>
                    option.children.toLowerCase().indexOf(input.toLowerCase()) >= 0
                  }
                >
                  {images.map(image => (
                    <Option key={image.id} value={image.id}>
                      {image.name} ({image.os_type} {image.version})
                    </Option>
                  ))}
                </Select>
              </Form.Item>

              <Divider>Resource Configuration</Divider>

              <Row gutter={16}>
                <Col span={12}>
                  <Form.Item
                    name="cpu_cores"
                    label="CPU Cores"
                    rules={[{ required: true, message: 'Please input CPU cores!' }]}
                  >
                    <InputNumber min={1} max={32} style={{ width: '100%' }} />
                  </Form.Item>
                </Col>
                <Col span={12}>
                  <Form.Item
                    name="memory_mb"
                    label="Memory (MB)"
                    rules={[{ required: true, message: 'Please input memory!' }]}
                  >
                    <InputNumber min={1024} max={32768} style={{ width: '100%' }} />
                  </Form.Item>
                </Col>
              </Row>

              <Form.Item
                name="storage_mounts"
                label="Storage Mounts"
                initialValue={[{ mount_point: '/', storage_gb: 20, storage_type: 'standard' }]}
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
                          >
                            <Input placeholder="Mount point (e.g., /)" />
                          </Form.Item>
                          <Form.Item
                            {...restField}
                            name={[name, 'storage_gb']}
                            rules={[{ required: true, message: 'Missing storage size' }]}
                          >
                            <InputNumber placeholder="Size (GB)" min={1} max={1000} />
                          </Form.Item>
                          <Form.Item
                            {...restField}
                            name={[name, 'storage_type']}
                            rules={[{ required: true, message: 'Missing storage type' }]}
                          >
                            <Select placeholder="Type" style={{ width: 100 }}>
                              <Option value="standard">Standard</Option>
                              <Option value="ssd">SSD</Option>
                              <Option value="nvme">NVMe</Option>
                            </Select>
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
            </>
          )}

          {editingVM && (
            <>
              <Row gutter={16}>
                <Col span={12}>
                  <Form.Item
                    name="cpu_cores"
                    label="CPU Cores"
                    rules={[{ required: true, message: 'Please input CPU cores!' }]}
                  >
                    <InputNumber min={1} max={32} style={{ width: '100%' }} />
                  </Form.Item>
                </Col>
                <Col span={12}>
                  <Form.Item
                    name="memory_mb"
                    label="Memory (MB)"
                    rules={[{ required: true, message: 'Please input memory!' }]}
                  >
                    <InputNumber min={1024} max={32768} style={{ width: '100%' }} />
                  </Form.Item>
                </Col>
              </Row>
            </>
          )}

          <Form.Item style={{ marginBottom: 0, textAlign: 'right' }}>
            <Space>
              <Button onClick={() => setModalVisible(false)}>
                Cancel
              </Button>
              <Button type="primary" htmlType="submit">
                {editingVM ? 'Update' : 'Launch'}
              </Button>
            </Space>
          </Form.Item>
        </Form>
      </Modal>
    </div>
  );
};

export default VMManagement;