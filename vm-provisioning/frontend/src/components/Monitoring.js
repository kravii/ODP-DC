import React, { useState, useEffect } from 'react';
import {
  Card,
  CardContent,
  Typography,
  Box,
  Grid,
  LinearProgress,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  Chip,
  IconButton,
  Alert,
  CircularProgress,
  Select,
  MenuItem,
  FormControl,
  InputLabel
} from '@mui/material';
import {
  Refresh as RefreshIcon,
  Memory as MemoryIcon,
  Storage as StorageIcon,
  Speed as SpeedIcon,
  Computer as ComputerIcon,
  Warning as WarningIcon,
  Error as ErrorIcon,
  CheckCircle as CheckCircleIcon
} from '@mui/icons-material';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, BarChart, Bar } from 'recharts';
import { apiService } from '../services/api';

const Monitoring = () => {
  const [dashboardData, setDashboardData] = useState(null);
  const [vmMonitoringData, setVmMonitoringData] = useState([]);
  const [baremetalMonitoringData, setBaremetalMonitoringData] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [timeRange, setTimeRange] = useState('1h');
  const [selectedResource, setSelectedResource] = useState('all');

  const timeRanges = [
    { value: '1h', label: 'Last Hour' },
    { value: '6h', label: 'Last 6 Hours' },
    { value: '24h', label: 'Last 24 Hours' },
    { value: '7d', label: 'Last 7 Days' }
  ];

  const resourceTypes = [
    { value: 'all', label: 'All Resources' },
    { value: 'vms', label: 'Virtual Machines' },
    { value: 'baremetals', label: 'Baremetal Servers' }
  ];

  useEffect(() => {
    fetchMonitoringData();
    // Set up auto-refresh every 30 seconds
    const interval = setInterval(fetchMonitoringData, 30000);
    return () => clearInterval(interval);
  }, [timeRange, selectedResource]);

  const fetchMonitoringData = async () => {
    setLoading(true);
    try {
      const [dashboard, vmData, baremetalData] = await Promise.all([
        apiService.getDashboardData(),
        apiService.getVMMonitoringData(),
        apiService.getBaremetalMonitoringData()
      ]);
      
      setDashboardData(dashboard);
      setVmMonitoringData(vmData);
      setBaremetalMonitoringData(baremetalData);
      setError(null);
    } catch (err) {
      setError('Failed to fetch monitoring data: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  const getUsageColor = (usage) => {
    if (usage > 90) return 'error';
    if (usage > 75) return 'warning';
    return 'success';
  };

  const getStatusIcon = (status) => {
    switch (status) {
      case 'running':
      case 'active':
        return <CheckCircleIcon color="success" />;
      case 'stopped':
      case 'inactive':
        return <WarningIcon color="warning" />;
      case 'error':
        return <ErrorIcon color="error" />;
      default:
        return <WarningIcon color="warning" />;
    }
  };

  const formatBytes = (bytes) => {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  };

  const formatUptime = (seconds) => {
    const days = Math.floor(seconds / 86400);
    const hours = Math.floor((seconds % 86400) / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    return `${days}d ${hours}h ${minutes}m`;
  };

  // Generate sample time series data for charts
  const generateTimeSeriesData = (data, metric) => {
    const now = new Date();
    return Array.from({ length: 24 }, (_, i) => {
      const time = new Date(now.getTime() - (23 - i) * 60 * 60 * 1000);
      return {
        time: time.toLocaleTimeString(),
        value: data[metric] + (Math.random() - 0.5) * 10
      };
    });
  };

  if (loading && !dashboardData) {
    return (
      <Box display="flex" justifyContent="center" alignItems="center" minHeight="400px">
        <CircularProgress />
      </Box>
    );
  }

  return (
    <Box>
      <Box display="flex" justifyContent="space-between" alignItems="center" mb={3}>
        <Typography variant="h4" component="h1">
          Monitoring Dashboard
        </Typography>
        <Box display="flex" gap={2}>
          <FormControl size="small" sx={{ minWidth: 120 }}>
            <InputLabel>Time Range</InputLabel>
            <Select
              value={timeRange}
              onChange={(e) => setTimeRange(e.target.value)}
            >
              {timeRanges.map((range) => (
                <MenuItem key={range.value} value={range.value}>
                  {range.label}
                </MenuItem>
              ))}
            </Select>
          </FormControl>
          <FormControl size="small" sx={{ minWidth: 150 }}>
            <InputLabel>Resource Type</InputLabel>
            <Select
              value={selectedResource}
              onChange={(e) => setSelectedResource(e.target.value)}
            >
              {resourceTypes.map((type) => (
                <MenuItem key={type.value} value={type.value}>
                  {type.label}
                </MenuItem>
              ))}
            </Select>
          </FormControl>
          <IconButton onClick={fetchMonitoringData} disabled={loading}>
            <RefreshIcon />
          </IconButton>
        </Box>
      </Box>

      {error && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      {dashboardData && (
        <>
          {/* Overview Cards */}
          <Grid container spacing={3} mb={3}>
            <Grid item xs={12} sm={6} md={3}>
              <Card>
                <CardContent>
                  <Box display="flex" alignItems="center">
                    <ComputerIcon color="primary" sx={{ mr: 2 }} />
                    <Box>
                      <Typography variant="h4">{dashboardData.total_vms}</Typography>
                      <Typography color="textSecondary">Total VMs</Typography>
                      <Typography variant="caption" color="success">
                        {dashboardData.running_vms} Running
                      </Typography>
                    </Box>
                  </Box>
                </CardContent>
              </Card>
            </Grid>
            <Grid item xs={12} sm={6} md={3}>
              <Card>
                <CardContent>
                  <Box display="flex" alignItems="center">
                    <StorageIcon color="primary" sx={{ mr: 2 }} />
                    <Box>
                      <Typography variant="h4">{dashboardData.total_baremetals}</Typography>
                      <Typography color="textSecondary">Baremetal Servers</Typography>
                      <Typography variant="caption" color="success">
                        {dashboardData.active_baremetals} Active
                      </Typography>
                    </Box>
                  </Box>
                </CardContent>
              </Card>
            </Grid>
            <Grid item xs={12} sm={6} md={3}>
              <Card>
                <CardContent>
                  <Box display="flex" alignItems="center">
                    <SpeedIcon color="primary" sx={{ mr: 2 }} />
                    <Box>
                      <Typography variant="h4">
                        {dashboardData.used_cpu_cores}/{dashboardData.total_cpu_cores}
                      </Typography>
                      <Typography color="textSecondary">CPU Cores</Typography>
                      <LinearProgress
                        variant="determinate"
                        value={(dashboardData.used_cpu_cores / dashboardData.total_cpu_cores) * 100}
                        color={getUsageColor((dashboardData.used_cpu_cores / dashboardData.total_cpu_cores) * 100)}
                        sx={{ mt: 1 }}
                      />
                    </Box>
                  </Box>
                </CardContent>
              </Card>
            </Grid>
            <Grid item xs={12} sm={6} md={3}>
              <Card>
                <CardContent>
                  <Box display="flex" alignItems="center">
                    <MemoryIcon color="primary" sx={{ mr: 2 }} />
                    <Box>
                      <Typography variant="h4">
                        {dashboardData.used_memory_gb}/{dashboardData.total_memory_gb}GB
                      </Typography>
                      <Typography color="textSecondary">Memory</Typography>
                      <LinearProgress
                        variant="determinate"
                        value={(dashboardData.used_memory_gb / dashboardData.total_memory_gb) * 100}
                        color={getUsageColor((dashboardData.used_memory_gb / dashboardData.total_memory_gb) * 100)}
                        sx={{ mt: 1 }}
                      />
                    </Box>
                  </Box>
                </CardContent>
              </Card>
            </Grid>
          </Grid>

          {/* Resource Usage Charts */}
          <Grid container spacing={3} mb={3}>
            <Grid item xs={12} md={6}>
              <Card>
                <CardContent>
                  <Typography variant="h6" gutterBottom>
                    CPU Usage Over Time
                  </Typography>
                  <ResponsiveContainer width="100%" height={300}>
                    <LineChart data={generateTimeSeriesData(dashboardData, 'used_cpu_cores')}>
                      <CartesianGrid strokeDasharray="3 3" />
                      <XAxis dataKey="time" />
                      <YAxis />
                      <Tooltip />
                      <Legend />
                      <Line type="monotone" dataKey="value" stroke="#8884d8" strokeWidth={2} />
                    </LineChart>
                  </ResponsiveContainer>
                </CardContent>
              </Card>
            </Grid>
            <Grid item xs={12} md={6}>
              <Card>
                <CardContent>
                  <Typography variant="h6" gutterBottom>
                    Memory Usage Over Time
                  </Typography>
                  <ResponsiveContainer width="100%" height={300}>
                    <LineChart data={generateTimeSeriesData(dashboardData, 'used_memory_gb')}>
                      <CartesianGrid strokeDasharray="3 3" />
                      <XAxis dataKey="time" />
                      <YAxis />
                      <Tooltip />
                      <Legend />
                      <Line type="monotone" dataKey="value" stroke="#82ca9d" strokeWidth={2} />
                    </LineChart>
                  </ResponsiveContainer>
                </CardContent>
              </Card>
            </Grid>
          </Grid>

          {/* VM Monitoring Table */}
          {(selectedResource === 'all' || selectedResource === 'vms') && (
            <Card sx={{ mb: 3 }}>
              <CardContent>
                <Typography variant="h6" gutterBottom>
                  Virtual Machine Status
                </Typography>
                <TableContainer component={Paper}>
                  <Table>
                    <TableHead>
                      <TableRow>
                        <TableCell>VM Name</TableCell>
                        <TableCell>Status</TableCell>
                        <TableCell>CPU Usage</TableCell>
                        <TableCell>Memory Usage</TableCell>
                        <TableCell>Storage Usage</TableCell>
                        <TableCell>Network I/O</TableCell>
                        <TableCell>Uptime</TableCell>
                        <TableCell>Last Updated</TableCell>
                      </TableRow>
                    </TableHead>
                    <TableBody>
                      {vmMonitoringData.map((vm) => (
                        <TableRow key={vm.vm_id}>
                          <TableCell>
                            <Box display="flex" alignItems="center">
                              {getStatusIcon(vm.status)}
                              <Typography sx={{ ml: 1 }}>{vm.vm_name}</Typography>
                            </Box>
                          </TableCell>
                          <TableCell>
                            <Chip
                              label={vm.status}
                              color={getUsageColor(vm.cpu_usage)}
                              size="small"
                            />
                          </TableCell>
                          <TableCell>
                            <Box>
                              <Typography variant="caption">{vm.cpu_usage.toFixed(1)}%</Typography>
                              <LinearProgress
                                variant="determinate"
                                value={vm.cpu_usage}
                                color={getUsageColor(vm.cpu_usage)}
                                sx={{ mt: 0.5 }}
                              />
                            </Box>
                          </TableCell>
                          <TableCell>
                            <Box>
                              <Typography variant="caption">{vm.memory_usage.toFixed(1)}%</Typography>
                              <LinearProgress
                                variant="determinate"
                                value={vm.memory_usage}
                                color={getUsageColor(vm.memory_usage)}
                                sx={{ mt: 0.5 }}
                              />
                            </Box>
                          </TableCell>
                          <TableCell>
                            <Box>
                              <Typography variant="caption">{vm.storage_usage.toFixed(1)}%</Typography>
                              <LinearProgress
                                variant="determinate"
                                value={vm.storage_usage}
                                color={getUsageColor(vm.storage_usage)}
                                sx={{ mt: 0.5 }}
                              />
                            </Box>
                          </TableCell>
                          <TableCell>
                            <Typography variant="caption">
                              ↓ {formatBytes(vm.network_in)}/s<br />
                              ↑ {formatBytes(vm.network_out)}/s
                            </Typography>
                          </TableCell>
                          <TableCell>
                            <Typography variant="caption">
                              {formatUptime(vm.uptime)}
                            </Typography>
                          </TableCell>
                          <TableCell>
                            <Typography variant="caption">
                              {new Date(vm.last_updated).toLocaleString()}
                            </Typography>
                          </TableCell>
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                </TableContainer>
              </CardContent>
            </Card>
          )}

          {/* Baremetal Monitoring Table */}
          {(selectedResource === 'all' || selectedResource === 'baremetals') && (
            <Card>
              <CardContent>
                <Typography variant="h6" gutterBottom>
                  Baremetal Server Status
                </Typography>
                <TableContainer component={Paper}>
                  <Table>
                    <TableHead>
                      <TableRow>
                        <TableCell>Server Name</TableCell>
                        <TableCell>Status</TableCell>
                        <TableCell>CPU Usage</TableCell>
                        <TableCell>Memory Usage</TableCell>
                        <TableCell>Storage Usage</TableCell>
                        <TableCell>Temperature</TableCell>
                        <TableCell>Network I/O</TableCell>
                        <TableCell>Uptime</TableCell>
                        <TableCell>Last Updated</TableCell>
                      </TableRow>
                    </TableHead>
                    <TableBody>
                      {baremetalMonitoringData.map((server) => (
                        <TableRow key={server.server_id}>
                          <TableCell>
                            <Box display="flex" alignItems="center">
                              {getStatusIcon(server.status)}
                              <Typography sx={{ ml: 1 }}>{server.server_name}</Typography>
                            </Box>
                          </TableCell>
                          <TableCell>
                            <Chip
                              label={server.status}
                              color={getUsageColor(server.cpu_usage)}
                              size="small"
                            />
                          </TableCell>
                          <TableCell>
                            <Box>
                              <Typography variant="caption">{server.cpu_usage.toFixed(1)}%</Typography>
                              <LinearProgress
                                variant="determinate"
                                value={server.cpu_usage}
                                color={getUsageColor(server.cpu_usage)}
                                sx={{ mt: 0.5 }}
                              />
                            </Box>
                          </TableCell>
                          <TableCell>
                            <Box>
                              <Typography variant="caption">{server.memory_usage.toFixed(1)}%</Typography>
                              <LinearProgress
                                variant="determinate"
                                value={server.memory_usage}
                                color={getUsageColor(server.memory_usage)}
                                sx={{ mt: 0.5 }}
                              />
                            </Box>
                          </TableCell>
                          <TableCell>
                            <Box>
                              <Typography variant="caption">{server.storage_usage.toFixed(1)}%</Typography>
                              <LinearProgress
                                variant="determinate"
                                value={server.storage_usage}
                                color={getUsageColor(server.storage_usage)}
                                sx={{ mt: 0.5 }}
                              />
                            </Box>
                          </TableCell>
                          <TableCell>
                            <Typography variant="caption">
                              {server.temperature ? `${server.temperature.toFixed(1)}°C` : 'N/A'}
                            </Typography>
                          </TableCell>
                          <TableCell>
                            <Typography variant="caption">
                              ↓ {formatBytes(server.network_in)}/s<br />
                              ↑ {formatBytes(server.network_out)}/s
                            </Typography>
                          </TableCell>
                          <TableCell>
                            <Typography variant="caption">
                              {formatUptime(server.uptime)}
                            </Typography>
                          </TableCell>
                          <TableCell>
                            <Typography variant="caption">
                              {new Date(server.last_updated).toLocaleString()}
                            </Typography>
                          </TableCell>
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                </TableContainer>
              </CardContent>
            </Card>
          )}
        </>
      )}
    </Box>
  );
};

export default Monitoring;