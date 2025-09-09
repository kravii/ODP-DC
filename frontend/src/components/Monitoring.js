import React, { useState, useEffect } from 'react';
import { 
  Card, 
  Row, 
  Col, 
  Table, 
  Tag, 
  Button, 
  Space, 
  Select, 
  DatePicker, 
  Statistic,
  Progress,
  Alert,
  Tabs
} from 'antd';
import { 
  ReloadOutlined, 
  CheckCircleOutlined, 
  ExclamationCircleOutlined,
  CloseCircleOutlined,
  AlertOutlined
} from '@ant-design/icons';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, PieChart, Pie, Cell } from 'recharts';
import { apiService } from '../services/api';
import moment from 'moment';

const { RangePicker } = DatePicker;
const { Option } = Select;
const { TabPane } = Tabs;

const Monitoring = () => {
  const [healthData, setHealthData] = useState(null);
  const [utilizationData, setUtilizationData] = useState(null);
  const [alerts, setAlerts] = useState([]);
  const [metrics, setMetrics] = useState([]);
  const [loading, setLoading] = useState(false);
  const [timeRange, setTimeRange] = useState('24h');
  const [resourceType, setResourceType] = useState('all');

  useEffect(() => {
    fetchMonitoringData();
    const interval = setInterval(fetchMonitoringData, 30000); // Refresh every 30 seconds
    return () => clearInterval(interval);
  }, [timeRange, resourceType]);

  const fetchMonitoringData = async () => {
    setLoading(true);
    try {
      const [health, utilization, alertsData, metricsData] = await Promise.all([
        apiService.monitoring.getHealth(),
        apiService.monitoring.getUtilization(),
        apiService.monitoring.getAlerts({ limit: 50 }),
        apiService.monitoring.getMetrics({
          hours: timeRange === '1h' ? 1 : timeRange === '24h' ? 24 : 168,
          resource_type: resourceType === 'all' ? undefined : resourceType
        })
      ]);
      
      setHealthData(health.data);
      setUtilizationData(utilization.data);
      setAlerts(alertsData.data);
      setMetrics(metricsData.data);
    } catch (error) {
      console.error('Error fetching monitoring data:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleResolveAlert = async (alertId) => {
    try {
      await apiService.monitoring.resolveAlert(alertId);
      message.success('Alert resolved successfully');
      fetchMonitoringData();
    } catch (error) {
      message.error('Failed to resolve alert');
    }
  };

  const getSeverityColor = (severity) => {
    switch (severity) {
      case 'critical': return 'red';
      case 'high': return 'orange';
      case 'medium': return 'blue';
      case 'low': return 'green';
      default: return 'default';
    }
  };

  const alertColumns = [
    {
      title: 'Severity',
      dataIndex: 'severity',
      key: 'severity',
      render: (severity) => (
        <Tag color={getSeverityColor(severity)}>
          {severity.toUpperCase()}
        </Tag>
      ),
      filters: [
        { text: 'Critical', value: 'critical' },
        { text: 'High', value: 'high' },
        { text: 'Medium', value: 'medium' },
        { text: 'Low', value: 'low' },
      ],
      onFilter: (value, record) => record.severity === value,
    },
    {
      title: 'Type',
      dataIndex: 'alert_type',
      key: 'alert_type',
    },
    {
      title: 'Resource',
      dataIndex: 'resource_type',
      key: 'resource_type',
      render: (type) => type.toUpperCase(),
    },
    {
      title: 'Message',
      dataIndex: 'message',
      key: 'message',
      ellipsis: true,
    },
    {
      title: 'Status',
      dataIndex: 'is_resolved',
      key: 'is_resolved',
      render: (resolved) => (
        <Tag color={resolved ? 'green' : 'red'}>
          {resolved ? 'Resolved' : 'Active'}
        </Tag>
      ),
    },
    {
      title: 'Created',
      dataIndex: 'created_at',
      key: 'created_at',
      render: (time) => moment(time).format('YYYY-MM-DD HH:mm:ss'),
      sorter: (a, b) => moment(a.created_at).unix() - moment(b.created_at).unix(),
    },
    {
      title: 'Actions',
      key: 'actions',
      render: (_, record) => (
        !record.is_resolved && (
          <Button 
            size="small" 
            onClick={() => handleResolveAlert(record.id)}
          >
            Resolve
          </Button>
        )
      ),
    },
  ];

  // Process metrics data for charts
  const processMetricsData = () => {
    const cpuData = {};
    const memoryData = {};
    
    metrics.forEach(metric => {
      const time = moment(metric.timestamp).format('HH:mm');
      if (!cpuData[time]) {
        cpuData[time] = { time, cpu: 0, memory: 0, count: 0 };
      }
      if (!memoryData[time]) {
        memoryData[time] = { time, cpu: 0, memory: 0, count: 0 };
      }
      
      if (metric.metric_name === 'cpu_usage') {
        cpuData[time].cpu += parseFloat(metric.metric_value);
        cpuData[time].count += 1;
      } else if (metric.metric_name === 'memory_usage') {
        memoryData[time].memory += parseFloat(metric.metric_value);
        memoryData[time].count += 1;
      }
    });
    
    // Calculate averages
    const chartData = Object.values(cpuData).map(item => ({
      time: item.time,
      cpu: item.count > 0 ? item.cpu / item.count : 0,
      memory: memoryData[item.time]?.count > 0 ? memoryData[item.time].memory / memoryData[item.time].count : 0
    }));
    
    return chartData.sort((a, b) => a.time.localeCompare(b.time));
  };

  const chartData = processMetricsData();

  const pieData = [
    { name: 'Active Alerts', value: alerts.filter(a => !a.is_resolved).length, color: '#ff4d4f' },
    { name: 'Resolved Alerts', value: alerts.filter(a => a.is_resolved).length, color: '#52c41a' },
  ];

  return (
    <div>
      <Row gutter={[16, 16]} style={{ marginBottom: 16 }}>
        <Col xs={24} sm={6}>
          <Card>
            <Statistic
              title="System Health"
              value={healthData?.overall_status?.toUpperCase() || 'UNKNOWN'}
              valueStyle={{ 
                color: healthData?.overall_status === 'healthy' ? '#3f8600' : '#faad14' 
              }}
              prefix={healthData?.overall_status === 'healthy' ? 
                <CheckCircleOutlined /> : <ExclamationCircleOutlined />}
            />
          </Card>
        </Col>
        <Col xs={24} sm={6}>
          <Card>
            <Statistic
              title="Active Alerts"
              value={alerts.filter(a => !a.is_resolved).length}
              valueStyle={{ color: '#ff4d4f' }}
              prefix={<AlertOutlined />}
            />
          </Card>
        </Col>
        <Col xs={24} sm={6}>
          <Card>
            <Statistic
              title="Baremetal CPU Usage"
              value={utilizationData?.baremetal?.cpu_usage_percent || 0}
              suffix="%"
              valueStyle={{ 
                color: (utilizationData?.baremetal?.cpu_usage_percent || 0) > 80 ? '#ff4d4f' : '#3f8600' 
              }}
            />
          </Card>
        </Col>
        <Col xs={24} sm={6}>
          <Card>
            <Statistic
              title="Baremetal Memory Usage"
              value={utilizationData?.baremetal?.memory_usage_percent || 0}
              suffix="%"
              valueStyle={{ 
                color: (utilizationData?.baremetal?.memory_usage_percent || 0) > 85 ? '#ff4d4f' : '#3f8600' 
              }}
            />
          </Card>
        </Col>
      </Row>

      <Tabs defaultActiveKey="overview">
        <TabPane tab="Overview" key="overview">
          <Row gutter={[16, 16]}>
            <Col xs={24} lg={12}>
              <Card title="Resource Usage Trend" extra={
                <Space>
                  <Select value={timeRange} onChange={setTimeRange} style={{ width: 100 }}>
                    <Option value="1h">1 Hour</Option>
                    <Option value="24h">24 Hours</Option>
                    <Option value="7d">7 Days</Option>
                  </Select>
                  <Button icon={<ReloadOutlined />} onClick={fetchMonitoringData} loading={loading} />
                </Space>
              }>
                <ResponsiveContainer width="100%" height={300}>
                  <LineChart data={chartData}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="time" />
                    <YAxis domain={[0, 100]} />
                    <Tooltip formatter={(value, name) => [`${value.toFixed(2)}%`, name === 'cpu' ? 'CPU' : 'Memory']} />
                    <Line type="monotone" dataKey="cpu" stroke="#1890ff" strokeWidth={2} name="CPU" />
                    <Line type="monotone" dataKey="memory" stroke="#52c41a" strokeWidth={2} name="Memory" />
                  </LineChart>
                </ResponsiveContainer>
              </Card>
            </Col>
            
            <Col xs={24} lg={12}>
              <Card title="Alert Distribution">
                <ResponsiveContainer width="100%" height={300}>
                  <PieChart>
                    <Pie
                      data={pieData}
                      cx="50%"
                      cy="50%"
                      innerRadius={60}
                      outerRadius={100}
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
          </Row>
        </TabPane>

        <TabPane tab="Alerts" key="alerts">
          <Card
            title="System Alerts"
            extra={
              <Space>
                <Select value={resourceType} onChange={setResourceType} style={{ width: 120 }}>
                  <Option value="all">All Resources</Option>
                  <Option value="baremetal">Baremetals</Option>
                  <Option value="vm">VMs</Option>
                </Select>
                <Button icon={<ReloadOutlined />} onClick={fetchMonitoringData} loading={loading} />
              </Space>
            }
          >
            <Table
              columns={alertColumns}
              dataSource={alerts}
              rowKey="id"
              loading={loading}
              pagination={{
                pageSize: 20,
                showSizeChanger: true,
                showQuickJumper: true,
                showTotal: (total, range) => 
                  `${range[0]}-${range[1]} of ${total} alerts`,
              }}
            />
          </Card>
        </TabPane>

        <TabPane tab="Metrics" key="metrics">
          <Row gutter={[16, 16]}>
            <Col xs={24} lg={12}>
              <Card title="CPU Utilization">
                <div style={{ marginBottom: 16 }}>
                  <div>Baremetal CPU: {utilizationData?.baremetal?.cpu_usage_percent || 0}%</div>
                  <Progress 
                    percent={utilizationData?.baremetal?.cpu_usage_percent || 0} 
                    status={utilizationData?.baremetal?.cpu_usage_percent > 80 ? 'exception' : 'normal'}
                  />
                </div>
                <div>
                  <div>VM CPU: {utilizationData?.vm?.cpu_usage_percent || 0}%</div>
                  <Progress 
                    percent={utilizationData?.vm?.cpu_usage_percent || 0} 
                    status={utilizationData?.vm?.cpu_usage_percent > 80 ? 'exception' : 'normal'}
                  />
                </div>
              </Card>
            </Col>
            
            <Col xs={24} lg={12}>
              <Card title="Memory Utilization">
                <div style={{ marginBottom: 16 }}>
                  <div>Baremetal Memory: {utilizationData?.baremetal?.memory_usage_percent || 0}%</div>
                  <Progress 
                    percent={utilizationData?.baremetal?.memory_usage_percent || 0} 
                    status={utilizationData?.baremetal?.memory_usage_percent > 85 ? 'exception' : 'normal'}
                  />
                </div>
                <div>
                  <div>VM Memory: {utilizationData?.vm?.memory_usage_percent || 0}%</div>
                  <Progress 
                    percent={utilizationData?.vm?.memory_usage_percent || 0} 
                    status={utilizationData?.vm?.memory_usage_percent > 85 ? 'exception' : 'normal'}
                  />
                </div>
              </Card>
            </Col>
          </Row>
        </TabPane>
      </Tabs>
    </div>
  );
};

export default Monitoring;