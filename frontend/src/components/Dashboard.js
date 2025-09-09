import React, { useState, useEffect } from 'react';
import { Row, Col, Card, Statistic, Table, Tag, Progress, Alert } from 'antd';
import { 
  ServerOutlined, 
  CloudServerOutlined, 
  AlertOutlined,
  CheckCircleOutlined,
  ExclamationCircleOutlined
} from '@ant-design/icons';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, PieChart, Pie, Cell } from 'recharts';
import { apiService } from '../services/api';

const Dashboard = () => {
  const [healthData, setHealthData] = useState(null);
  const [utilizationData, setUtilizationData] = useState(null);
  const [recentAlerts, setRecentAlerts] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchDashboardData();
    const interval = setInterval(fetchDashboardData, 30000); // Refresh every 30 seconds
    return () => clearInterval(interval);
  }, []);

  const fetchDashboardData = async () => {
    try {
      const [health, utilization, alerts] = await Promise.all([
        apiService.monitoring.getHealth(),
        apiService.monitoring.getUtilization(),
        apiService.monitoring.getAlerts({ limit: 5 })
      ]);
      
      setHealthData(health.data);
      setUtilizationData(utilization.data);
      setRecentAlerts(alerts.data);
    } catch (error) {
      console.error('Error fetching dashboard data:', error);
    } finally {
      setLoading(false);
    }
  };

  const getStatusColor = (status) => {
    switch (status) {
      case 'healthy': return '#52c41a';
      case 'degraded': return '#faad14';
      case 'critical': return '#ff4d4f';
      default: return '#d9d9d9';
    }
  };

  const getStatusIcon = (status) => {
    switch (status) {
      case 'healthy': return <CheckCircleOutlined />;
      case 'degraded': return <ExclamationCircleOutlined />;
      case 'critical': return <AlertOutlined />;
      default: return <ExclamationCircleOutlined />;
    }
  };

  const alertColumns = [
    {
      title: 'Severity',
      dataIndex: 'severity',
      key: 'severity',
      render: (severity) => (
        <Tag color={severity === 'critical' ? 'red' : severity === 'high' ? 'orange' : 'blue'}>
          {severity.toUpperCase()}
        </Tag>
      ),
    },
    {
      title: 'Type',
      dataIndex: 'alert_type',
      key: 'alert_type',
    },
    {
      title: 'Message',
      dataIndex: 'message',
      key: 'message',
      ellipsis: true,
    },
    {
      title: 'Time',
      dataIndex: 'created_at',
      key: 'created_at',
      render: (time) => new Date(time).toLocaleString(),
    },
  ];

  const pieData = healthData ? [
    { name: 'Active Baremetals', value: healthData.baremetals.active, color: '#52c41a' },
    { name: 'Failed Baremetals', value: healthData.baremetals.failed, color: '#ff4d4f' },
  ] : [];

  const lineData = [
    { name: '00:00', cpu: 45, memory: 60 },
    { name: '04:00', cpu: 52, memory: 65 },
    { name: '08:00', cpu: 68, memory: 70 },
    { name: '12:00', cpu: 75, memory: 75 },
    { name: '16:00', cpu: 70, memory: 72 },
    { name: '20:00', cpu: 55, memory: 68 },
  ];

  if (loading) {
    return <div>Loading dashboard...</div>;
  }

  return (
    <div>
      <Row gutter={[16, 16]}>
        {/* Health Status */}
        <Col span={24}>
          <Card>
            <div style={{ display: 'flex', alignItems: 'center', marginBottom: 16 }}>
              {getStatusIcon(healthData?.overall_status)}
              <h2 style={{ margin: '0 0 0 8px' }}>System Health</h2>
            </div>
            <Alert
              message={`Overall Status: ${healthData?.overall_status?.toUpperCase()}`}
              type={healthData?.overall_status === 'healthy' ? 'success' : 'warning'}
              showIcon
            />
          </Card>
        </Col>

        {/* Statistics Cards */}
        <Col xs={24} sm={12} lg={6}>
          <Card className="dashboard-card">
            <Statistic
              title="Total Baremetals"
              value={healthData?.baremetals?.total || 0}
              prefix={<ServerOutlined />}
            />
          </Card>
        </Col>
        <Col xs={24} sm={12} lg={6}>
          <Card className="dashboard-card">
            <Statistic
              title="Active Baremetals"
              value={healthData?.baremetals?.active || 0}
              prefix={<CheckCircleOutlined />}
            />
          </Card>
        </Col>
        <Col xs={24} sm={12} lg={6}>
          <Card className="dashboard-card">
            <Statistic
              title="Running VMs"
              value={healthData?.vms?.running || 0}
              prefix={<CloudServerOutlined />}
            />
          </Card>
        </Col>
        <Col xs={24} sm={12} lg={6}>
          <Card className="dashboard-card">
            <Statistic
              title="Active Alerts"
              value={healthData?.alerts?.active || 0}
              prefix={<AlertOutlined />}
            />
          </Card>
        </Col>

        {/* Resource Utilization */}
        <Col xs={24} lg={12}>
          <Card title="Resource Utilization" extra="Last 24 hours">
            <div className="resource-utilization">
              <div className="resource-item">
                <div className="resource-value">
                  {utilizationData?.baremetal?.cpu_usage_percent || 0}%
                </div>
                <div className="resource-label">Baremetal CPU</div>
                <Progress 
                  percent={utilizationData?.baremetal?.cpu_usage_percent || 0} 
                  size="small" 
                  status={utilizationData?.baremetal?.cpu_usage_percent > 80 ? 'exception' : 'normal'}
                />
              </div>
              <div className="resource-item">
                <div className="resource-value">
                  {utilizationData?.baremetal?.memory_usage_percent || 0}%
                </div>
                <div className="resource-label">Baremetal Memory</div>
                <Progress 
                  percent={utilizationData?.baremetal?.memory_usage_percent || 0} 
                  size="small"
                  status={utilizationData?.baremetal?.memory_usage_percent > 85 ? 'exception' : 'normal'}
                />
              </div>
            </div>
          </Card>
        </Col>

        {/* Baremetal Status Distribution */}
        <Col xs={24} lg={12}>
          <Card title="Baremetal Status Distribution">
            <ResponsiveContainer width="100%" height={200}>
              <PieChart>
                <Pie
                  data={pieData}
                  cx="50%"
                  cy="50%"
                  innerRadius={40}
                  outerRadius={80}
                  dataKey="value"
                >
                  {pieData.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={entry.color} />
                  ))}
                </Pie>
                <Tooltip />
              </PieChart>
            </ResponsiveContainer>
          </Card>
        </Col>

        {/* Resource Usage Trend */}
        <Col xs={24} lg={12}>
          <Card title="Resource Usage Trend">
            <ResponsiveContainer width="100%" height={200}>
              <LineChart data={lineData}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="name" />
                <YAxis />
                <Tooltip />
                <Line type="monotone" dataKey="cpu" stroke="#1890ff" strokeWidth={2} />
                <Line type="monotone" dataKey="memory" stroke="#52c41a" strokeWidth={2} />
              </LineChart>
            </ResponsiveContainer>
          </Card>
        </Col>

        {/* Recent Alerts */}
        <Col xs={24} lg={12}>
          <Card title="Recent Alerts" extra={<a href="/monitoring">View All</a>}>
            <Table
              dataSource={recentAlerts}
              columns={alertColumns}
              pagination={false}
              size="small"
              rowKey="id"
            />
          </Card>
        </Col>
      </Row>
    </div>
  );
};

export default Dashboard;