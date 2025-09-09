import React, { useState, useEffect } from 'react';
import { 
  Table, 
  Button, 
  Modal, 
  Form, 
  Input, 
  Space, 
  Popconfirm, 
  message, 
  Card, 
  Row, 
  Col, 
  Statistic,
  Tag,
  Tooltip,
  Switch,
  Upload
} from 'antd';
import { 
  PlusOutlined, 
  EditOutlined, 
  DeleteOutlined, 
  ReloadOutlined,
  KeyOutlined,
  CheckCircleOutlined,
  UploadOutlined
} from '@ant-design/icons';
import { apiService } from '../services/api';

const { TextArea } = Input;

const SSHKeyManagement = () => {
  const [sshKeys, setSshKeys] = useState([]);
  const [loading, setLoading] = useState(false);
  const [modalVisible, setModalVisible] = useState(false);
  const [editingKey, setEditingKey] = useState(null);
  const [form] = Form.useForm();

  useEffect(() => {
    fetchSSHKeys();
  }, []);

  const fetchSSHKeys = async () => {
    setLoading(true);
    try {
      const response = await apiService.ssh.getAll();
      setSshKeys(response.data);
    } catch (error) {
      message.error('Failed to fetch SSH keys');
    } finally {
      setLoading(false);
    }
  };

  const handleAdd = () => {
    setEditingKey(null);
    form.resetFields();
    setModalVisible(true);
  };

  const handleEdit = (record) => {
    setEditingKey(record);
    form.setFieldsValue({
      name: record.name,
      public_key: record.public_key,
      is_default: record.is_default,
    });
    setModalVisible(true);
  };

  const handleDelete = async (id) => {
    try {
      await apiService.ssh.delete(id);
      message.success('SSH key deleted successfully');
      fetchSSHKeys();
    } catch (error) {
      message.error('Failed to delete SSH key');
    }
  };

  const handleSubmit = async (values) => {
    try {
      if (editingKey) {
        await apiService.ssh.update(editingKey.id, values);
        message.success('SSH key updated successfully');
      } else {
        await apiService.ssh.create(values);
        message.success('SSH key created successfully');
      }
      setModalVisible(false);
      fetchSSHKeys();
    } catch (error) {
      message.error(error.response?.data?.detail || 'Operation failed');
    }
  };

  const handleFileUpload = (file) => {
    const reader = new FileReader();
    reader.onload = (e) => {
      const content = e.target.result;
      form.setFieldsValue({ public_key: content });
    };
    reader.readAsText(file);
    return false; // Prevent upload
  };

  const columns = [
    {
      title: 'Name',
      dataIndex: 'name',
      key: 'name',
      sorter: (a, b) => a.name.localeCompare(b.name),
    },
    {
      title: 'Public Key',
      dataIndex: 'public_key',
      key: 'public_key',
      render: (key) => (
        <div style={{ maxWidth: 200, overflow: 'hidden', textOverflow: 'ellipsis' }}>
          {key.substring(0, 50)}...
        </div>
      ),
    },
    {
      title: 'Default',
      dataIndex: 'is_default',
      key: 'is_default',
      render: (isDefault) => (
        <Tag color={isDefault ? 'green' : 'default'} icon={isDefault ? <CheckCircleOutlined /> : null}>
          {isDefault ? 'DEFAULT' : 'No'}
        </Tag>
      ),
      filters: [
        { text: 'Default', value: true },
        { text: 'Not Default', value: false },
      ],
      onFilter: (value, record) => record.is_default === value,
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
          <Tooltip title="Edit">
            <Button 
              type="text" 
              icon={<EditOutlined />} 
              onClick={() => handleEdit(record)}
            />
          </Tooltip>
          <Popconfirm
            title="Are you sure you want to delete this SSH key?"
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
        <Col xs={24} sm={8}>
          <Card>
            <Statistic
              title="Total SSH Keys"
              value={sshKeys.length}
              prefix={<KeyOutlined />}
            />
          </Card>
        </Col>
        <Col xs={24} sm={8}>
          <Card>
            <Statistic
              title="Default Keys"
              value={sshKeys.filter(k => k.is_default).length}
              valueStyle={{ color: '#3f8600' }}
            />
          </Card>
        </Col>
        <Col xs={24} sm={8}>
          <Card>
            <Statistic
              title="Active Keys"
              value={sshKeys.length}
              valueStyle={{ color: '#1890ff' }}
            />
          </Card>
        </Col>
      </Row>

      <Card
        title="SSH Key Management"
        extra={
          <Space>
            <Button 
              icon={<ReloadOutlined />} 
              onClick={fetchSSHKeys}
              loading={loading}
            >
              Refresh
            </Button>
            <Button 
              type="primary" 
              icon={<PlusOutlined />} 
              onClick={handleAdd}
            >
              Add SSH Key
            </Button>
          </Space>
        }
      >
        <Table
          columns={columns}
          dataSource={sshKeys}
          rowKey="id"
          loading={loading}
          pagination={{
            pageSize: 10,
            showSizeChanger: true,
            showQuickJumper: true,
            showTotal: (total, range) => 
              `${range[0]}-${range[1]} of ${total} SSH keys`,
          }}
        />
      </Card>

      <Modal
        title={editingKey ? 'Edit SSH Key' : 'Add SSH Key'}
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
          <Form.Item
            name="name"
            label="Key Name"
            rules={[{ required: true, message: 'Please input key name!' }]}
          >
            <Input placeholder="my-ssh-key" />
          </Form.Item>

          <Form.Item
            name="public_key"
            label="Public Key"
            rules={[{ required: true, message: 'Please input public key!' }]}
          >
            <TextArea 
              rows={4} 
              placeholder="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC..."
            />
          </Form.Item>

          <Form.Item>
            <Upload
              beforeUpload={handleFileUpload}
              showUploadList={false}
            >
              <Button icon={<UploadOutlined />}>
                Upload from File
              </Button>
            </Upload>
          </Form.Item>

          <Form.Item
            name="is_default"
            label="Set as Default"
            valuePropName="checked"
          >
            <Switch 
              checkedChildren="Yes" 
              unCheckedChildren="No" 
            />
          </Form.Item>

          <Form.Item style={{ marginBottom: 0, textAlign: 'right' }}>
            <Space>
              <Button onClick={() => setModalVisible(false)}>
                Cancel
              </Button>
              <Button type="primary" htmlType="submit">
                {editingKey ? 'Update' : 'Add'}
              </Button>
            </Space>
          </Form.Item>
        </Form>
      </Modal>
    </div>
  );
};

export default SSHKeyManagement;