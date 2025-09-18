import React, { useState, useEffect } from 'react';
import {
  Card,
  CardContent,
  Typography,
  Button,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  Chip,
  IconButton,
  Tooltip,
  Box,
  Alert,
  CircularProgress,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  Grid,
  LinearProgress
} from '@mui/material';
import {
  Add as AddIcon,
  Refresh as RefreshIcon,
  PlayArrow as PlayIcon,
  Stop as StopIcon,
  Settings as SettingsIcon,
  Memory as MemoryIcon,
  Storage as StorageIcon,
  Speed as SpeedIcon
} from '@mui/icons-material';
import { apiService } from '../services/api';

const BaremetalManagement = () => {
  const [baremetals, setBaremetals] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [addDialogOpen, setAddDialogOpen] = useState(false);
  const [newServer, setNewServer] = useState({
    name: '',
    hostname: '',
    ip_address: '',
    server_type: 'cx41',
    cpu_cores: 4,
    memory_gb: 16,
    storage_gb: 80
  });

  const serverTypes = [
    { value: 'cx11', label: 'CX11 (1 CPU, 4GB RAM)', cpu: 1, memory: 4 },
    { value: 'cx21', label: 'CX21 (2 CPU, 8GB RAM)', cpu: 2, memory: 8 },
    { value: 'cx31', label: 'CX31 (2 CPU, 8GB RAM)', cpu: 2, memory: 8 },
    { value: 'cx41', label: 'CX41 (4 CPU, 16GB RAM)', cpu: 4, memory: 16 },
    { value: 'cx51', label: 'CX51 (8 CPU, 32GB RAM)', cpu: 8, memory: 32 }
  ];

  useEffect(() => {
    fetchBaremetals();
    // Set up auto-refresh every 30 seconds
    const interval = setInterval(fetchBaremetals, 30000);
    return () => clearInterval(interval);
  }, []);

  const fetchBaremetals = async () => {
    setLoading(true);
    try {
      const data = await apiService.getBaremetals();
      setBaremetals(data);
      setError(null);
    } catch (err) {
      setError('Failed to fetch baremetal servers: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleAddToCluster = async (serverId) => {
    try {
      setLoading(true);
      await apiService.addBaremetalToCluster(serverId);
      await fetchBaremetals();
    } catch (err) {
      setError('Failed to add server to cluster: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleRemoveFromCluster = async (serverId) => {
    if (window.confirm('Are you sure you want to remove this server from the cluster?')) {
      try {
        setLoading(true);
        await apiService.removeBaremetalFromCluster(serverId);
        await fetchBaremetals();
      } catch (err) {
        setError('Failed to remove server from cluster: ' + err.message);
      } finally {
        setLoading(false);
      }
    }
  };

  const handleAddNewServer = async () => {
    try {
      setLoading(true);
      await apiService.addBaremetalServer(newServer);
      setAddDialogOpen(false);
      setNewServer({
        name: '',
        hostname: '',
        ip_address: '',
        server_type: 'cx41',
        cpu_cores: 4,
        memory_gb: 16,
        storage_gb: 80
      });
      await fetchBaremetals();
    } catch (err) {
      setError('Failed to add server: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  const getStatusColor = (status) => {
    switch (status) {
      case 'active': return 'success';
      case 'inactive': return 'default';
      case 'maintenance': return 'warning';
      default: return 'default';
    }
  };

  const getClusterStatusColor = (status) => {
    switch (status) {
      case 'active': return 'success';
      case 'inactive': return 'default';
      default: return 'default';
    }
  };

  const getUsageColor = (usage) => {
    if (usage > 90) return 'error';
    if (usage > 75) return 'warning';
    return 'success';
  };

  const handleServerTypeChange = (serverType) => {
    const type = serverTypes.find(t => t.value === serverType);
    if (type) {
      setNewServer({
        ...newServer,
        server_type: serverType,
        cpu_cores: type.cpu,
        memory_gb: type.memory
      });
    }
  };

  return (
    <Box>
      <Box display="flex" justifyContent="space-between" alignItems="center" mb={3}>
        <Typography variant="h4" component="h1">
          Baremetal Server Management
        </Typography>
        <Box>
          <Button
            variant="outlined"
            startIcon={<AddIcon />}
            onClick={() => setAddDialogOpen(true)}
            sx={{ mr: 1 }}
          >
            Add Server
          </Button>
          <IconButton onClick={fetchBaremetals} disabled={loading}>
            <RefreshIcon />
          </IconButton>
        </Box>
      </Box>

      {error && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      <Card>
        <CardContent>
          <Typography variant="h6" gutterBottom>
            Baremetal Servers ({baremetals.length})
          </Typography>

          {loading ? (
            <Box display="flex" justifyContent="center" p={3}>
              <CircularProgress />
            </Box>
          ) : (
            <TableContainer component={Paper}>
              <Table>
                <TableHead>
                  <TableRow>
                    <TableCell>Name</TableCell>
                    <TableCell>Hostname</TableCell>
                    <TableCell>IP Address</TableCell>
                    <TableCell>Server Type</TableCell>
                    <TableCell>Resources</TableCell>
                    <TableCell>Status</TableCell>
                    <TableCell>Cluster Status</TableCell>
                    <TableCell>Resource Usage</TableCell>
                    <TableCell>Last Heartbeat</TableCell>
                    <TableCell>Actions</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {baremetals.map((server) => (
                    <TableRow key={server.id}>
                      <TableCell>{server.name}</TableCell>
                      <TableCell>{server.hostname}</TableCell>
                      <TableCell>{server.ip_address}</TableCell>
                      <TableCell>{server.server_type}</TableCell>
                      <TableCell>
                        {server.cpu_cores} CPU, {server.memory_gb}GB RAM, {server.storage_gb}GB Storage
                      </TableCell>
                      <TableCell>
                        <Chip
                          label={server.status}
                          color={getStatusColor(server.status)}
                          size="small"
                        />
                      </TableCell>
                      <TableCell>
                        <Chip
                          label={server.cluster_status}
                          color={getClusterStatusColor(server.cluster_status)}
                          size="small"
                        />
                      </TableCell>
                      <TableCell>
                        <Box sx={{ minWidth: 100 }}>
                          <Box display="flex" alignItems="center" mb={1}>
                            <SpeedIcon sx={{ mr: 1, fontSize: 16 }} />
                            <Typography variant="caption">CPU: {server.cpu_usage.toFixed(1)}%</Typography>
                          </Box>
                          <LinearProgress
                            variant="determinate"
                            value={server.cpu_usage}
                            color={getUsageColor(server.cpu_usage)}
                            sx={{ mb: 1 }}
                          />
                          <Box display="flex" alignItems="center" mb={1}>
                            <MemoryIcon sx={{ mr: 1, fontSize: 16 }} />
                            <Typography variant="caption">RAM: {server.memory_usage.toFixed(1)}%</Typography>
                          </Box>
                          <LinearProgress
                            variant="determinate"
                            value={server.memory_usage}
                            color={getUsageColor(server.memory_usage)}
                            sx={{ mb: 1 }}
                          />
                          <Box display="flex" alignItems="center">
                            <StorageIcon sx={{ mr: 1, fontSize: 16 }} />
                            <Typography variant="caption">Storage: {server.storage_usage.toFixed(1)}%</Typography>
                          </Box>
                          <LinearProgress
                            variant="determinate"
                            value={server.storage_usage}
                            color={getUsageColor(server.storage_usage)}
                          />
                        </Box>
                      </TableCell>
                      <TableCell>
                        {server.last_heartbeat ? 
                          new Date(server.last_heartbeat).toLocaleString() : 
                          'Never'
                        }
                      </TableCell>
                      <TableCell>
                        {server.cluster_status === 'active' ? (
                          <Tooltip title="Remove from Cluster">
                            <IconButton
                              size="small"
                              onClick={() => handleRemoveFromCluster(server.id)}
                              color="error"
                            >
                              <StopIcon />
                            </IconButton>
                          </Tooltip>
                        ) : (
                          <Tooltip title="Add to Cluster">
                            <IconButton
                              size="small"
                              onClick={() => handleAddToCluster(server.id)}
                              color="success"
                            >
                              <PlayIcon />
                            </IconButton>
                          </Tooltip>
                        )}
                        <Tooltip title="Server Settings">
                          <IconButton size="small">
                            <SettingsIcon />
                          </IconButton>
                        </Tooltip>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </TableContainer>
          )}
        </CardContent>
      </Card>

      {/* Add Server Dialog */}
      <Dialog
        open={addDialogOpen}
        onClose={() => setAddDialogOpen(false)}
        maxWidth="md"
        fullWidth
      >
        <DialogTitle>Add New Baremetal Server</DialogTitle>
        <DialogContent>
          <Grid container spacing={2} sx={{ mt: 1 }}>
            <Grid item xs={12} sm={6}>
              <TextField
                fullWidth
                label="Server Name"
                value={newServer.name}
                onChange={(e) => setNewServer({ ...newServer, name: e.target.value })}
                required
              />
            </Grid>
            <Grid item xs={12} sm={6}>
              <TextField
                fullWidth
                label="Hostname"
                value={newServer.hostname}
                onChange={(e) => setNewServer({ ...newServer, hostname: e.target.value })}
                required
              />
            </Grid>
            <Grid item xs={12} sm={6}>
              <TextField
                fullWidth
                label="IP Address"
                value={newServer.ip_address}
                onChange={(e) => setNewServer({ ...newServer, ip_address: e.target.value })}
                required
              />
            </Grid>
            <Grid item xs={12} sm={6}>
              <FormControl fullWidth>
                <InputLabel>Server Type</InputLabel>
                <Select
                  value={newServer.server_type}
                  onChange={(e) => handleServerTypeChange(e.target.value)}
                >
                  {serverTypes.map((type) => (
                    <MenuItem key={type.value} value={type.value}>
                      {type.label}
                    </MenuItem>
                  ))}
                </Select>
              </FormControl>
            </Grid>
            <Grid item xs={12} sm={4}>
              <TextField
                fullWidth
                label="CPU Cores"
                type="number"
                value={newServer.cpu_cores}
                onChange={(e) => setNewServer({ ...newServer, cpu_cores: parseInt(e.target.value) })}
                inputProps={{ min: 1, max: 32 }}
              />
            </Grid>
            <Grid item xs={12} sm={4}>
              <TextField
                fullWidth
                label="Memory (GB)"
                type="number"
                value={newServer.memory_gb}
                onChange={(e) => setNewServer({ ...newServer, memory_gb: parseInt(e.target.value) })}
                inputProps={{ min: 1, max: 128 }}
              />
            </Grid>
            <Grid item xs={12} sm={4}>
              <TextField
                fullWidth
                label="Storage (GB)"
                type="number"
                value={newServer.storage_gb}
                onChange={(e) => setNewServer({ ...newServer, storage_gb: parseInt(e.target.value) })}
                inputProps={{ min: 10, max: 1000 }}
              />
            </Grid>
          </Grid>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setAddDialogOpen(false)}>Cancel</Button>
          <Button
            onClick={handleAddNewServer}
            variant="contained"
            disabled={loading || !newServer.name || !newServer.hostname || !newServer.ip_address}
          >
            Add Server
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default BaremetalManagement;