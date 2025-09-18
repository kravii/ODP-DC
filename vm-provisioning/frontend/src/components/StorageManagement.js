import React, { useState, useEffect } from 'react';
import {
  Card,
  CardContent,
  Typography,
  Box,
  Grid,
  LinearProgress,
  Chip,
  Button,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  Alert,
  CircularProgress,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  IconButton,
  Tooltip
} from '@mui/material';
import {
  Storage as StorageIcon,
  Refresh as RefreshIcon,
  ExpandMore as ExpandIcon,
  Create as CreateIcon,
  Delete as DeleteIcon,
  Warning as WarningIcon,
  Error as ErrorIcon,
  CheckCircle as CheckCircleIcon
} from '@mui/icons-material';
import { apiService } from '../services/api';

const StorageManagement = () => {
  const [storageUsage, setStorageUsage] = useState({});
  const [storageHealth, setStorageHealth] = useState({});
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [resizeDialogOpen, setResizeDialogOpen] = useState(false);
  const [snapshotDialogOpen, setSnapshotDialogOpen] = useState(false);
  const [selectedVm, setSelectedVm] = useState(null);
  const [newSize, setNewSize] = useState('');
  const [snapshotName, setSnapshotName] = useState('');

  useEffect(() => {
    fetchStorageData();
    // Set up auto-refresh every 30 seconds
    const interval = setInterval(fetchStorageData, 30000);
    return () => clearInterval(interval);
  }, []);

  const fetchStorageData = async () => {
    setLoading(true);
    try {
      const [usageData, healthData] = await Promise.all([
        apiService.getStorageUsage(),
        apiService.getStorageHealth()
      ]);
      setStorageUsage(usageData);
      setStorageHealth(healthData);
      setError(null);
    } catch (err) {
      setError('Failed to fetch storage data: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  const getStatusColor = (status) => {
    switch (status) {
      case 'healthy': return 'success';
      case 'warning': return 'warning';
      case 'critical': return 'error';
      default: return 'default';
    }
  };

  const getStatusIcon = (status) => {
    switch (status) {
      case 'healthy': return <CheckCircleIcon color="success" />;
      case 'warning': return <WarningIcon color="warning" />;
      case 'critical': return <ErrorIcon color="error" />;
      default: return <WarningIcon color="warning" />;
    }
  };

  const formatBytes = (bytes) => {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  };

  const handleResizeStorage = async () => {
    try {
      setLoading(true);
      await apiService.resizeVMStorage(selectedVm.id, parseInt(newSize));
      setResizeDialogOpen(false);
      setSelectedVm(null);
      setNewSize('');
      await fetchStorageData();
    } catch (err) {
      setError('Failed to resize storage: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleCreateSnapshot = async () => {
    try {
      setLoading(true);
      await apiService.createVMSnapshot(selectedVm.id, snapshotName);
      setSnapshotDialogOpen(false);
      setSelectedVm(null);
      setSnapshotName('');
      await fetchStorageData();
    } catch (err) {
      setError('Failed to create snapshot: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  const openResizeDialog = (vm) => {
    setSelectedVm(vm);
    setNewSize(vm.storage.toString());
    setResizeDialogOpen(true);
  };

  const openSnapshotDialog = (vm) => {
    setSelectedVm(vm);
    setSnapshotName(`snapshot-${new Date().toISOString().split('T')[0]}`);
    setSnapshotDialogOpen(true);
  };

  return (
    <Box>
      <Box display="flex" justifyContent="space-between" alignItems="center" mb={3}>
        <Typography variant="h4" component="h1">
          Storage Management
        </Typography>
        <IconButton onClick={fetchStorageData} disabled={loading}>
          <RefreshIcon />
        </IconButton>
      </Box>

      {error && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      {/* Storage Health Overview */}
      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Box display="flex" alignItems="center" mb={2}>
            {getStatusIcon(storageHealth.status)}
            <Typography variant="h6" sx={{ ml: 1 }}>
              Storage Health: {storageHealth.status?.toUpperCase()}
            </Typography>
          </Box>
          
          {storageHealth.warnings && storageHealth.warnings.length > 0 && (
            <Alert severity="warning" sx={{ mb: 2 }}>
              {storageHealth.warnings.map((warning, index) => (
                <div key={index}>{warning}</div>
              ))}
            </Alert>
          )}
          
          {storageHealth.errors && storageHealth.errors.length > 0 && (
            <Alert severity="error" sx={{ mb: 2 }}>
              {storageHealth.errors.map((error, index) => (
                <div key={index}>{error}</div>
              ))}
            </Alert>
          )}
        </CardContent>
      </Card>

      {/* Storage Usage Cards */}
      <Grid container spacing={3} mb={3}>
        {Object.entries(storageUsage).map(([name, stats]) => {
          if (name === 'total') return null;
          
          const usagePercentage = stats.usage_percentage || 0;
          const usedGB = stats.used_gb || 0;
          const limitGB = stats.limit_gb || 0;
          
          return (
            <Grid item xs={12} sm={6} md={4} key={name}>
              <Card>
                <CardContent>
                  <Box display="flex" alignItems="center" mb={2}>
                    <StorageIcon color="primary" sx={{ mr: 1 }} />
                    <Typography variant="h6" sx={{ textTransform: 'capitalize' }}>
                      {name.replace('_', ' ')}
                    </Typography>
                  </Box>
                  
                  <Typography variant="h4" color="primary">
                    {usedGB.toFixed(1)}GB
                  </Typography>
                  
                  <Typography color="textSecondary" gutterBottom>
                    of {limitGB}GB
                  </Typography>
                  
                  <LinearProgress
                    variant="determinate"
                    value={usagePercentage}
                    color={usagePercentage > 90 ? 'error' : usagePercentage > 75 ? 'warning' : 'primary'}
                    sx={{ mb: 1 }}
                  />
                  
                  <Typography variant="body2" color="textSecondary">
                    {usagePercentage.toFixed(1)}% used
                  </Typography>
                </CardContent>
              </Card>
            </Grid>
          );
        })}
      </Grid>

      {/* Total Storage Overview */}
      {storageUsage.total && (
        <Card sx={{ mb: 3 }}>
          <CardContent>
            <Typography variant="h6" gutterBottom>
              Total Storage Overview
            </Typography>
            
            <Box display="flex" alignItems="center" mb={2}>
              <Typography variant="h4" color="primary">
                {storageUsage.total.used_gb}GB
              </Typography>
              <Typography color="textSecondary" sx={{ ml: 1 }}>
                of {storageUsage.total.total_gb}GB
              </Typography>
            </Box>
            
            <LinearProgress
              variant="determinate"
              value={storageUsage.total.usage_percentage}
              color={storageUsage.total.usage_percentage > 90 ? 'error' : 'primary'}
              sx={{ mb: 1, height: 10 }}
            />
            
            <Typography variant="body2" color="textSecondary">
              {storageUsage.total.usage_percentage.toFixed(1)}% used
            </Typography>
          </CardContent>
        </Card>
      )}

      {/* Storage Allocation Table */}
      <Card>
        <CardContent>
          <Typography variant="h6" gutterBottom>
            Storage Allocation Details
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
                    <TableCell>Storage Type</TableCell>
                    <TableCell>Used</TableCell>
                    <TableCell>Limit</TableCell>
                    <TableCell>Available</TableCell>
                    <TableCell>Usage %</TableCell>
                    <TableCell>Status</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {Object.entries(storageUsage).map(([name, stats]) => {
                    const usagePercentage = stats.usage_percentage || 0;
                    const status = usagePercentage > 90 ? 'critical' : usagePercentage > 75 ? 'warning' : 'healthy';
                    
                    return (
                      <TableRow key={name}>
                        <TableCell sx={{ textTransform: 'capitalize' }}>
                          {name.replace('_', ' ')}
                        </TableCell>
                        <TableCell>{stats.used_gb?.toFixed(1)}GB</TableCell>
                        <TableCell>{stats.limit_gb}GB</TableCell>
                        <TableCell>{stats.available_gb?.toFixed(1)}GB</TableCell>
                        <TableCell>
                          <Box display="flex" alignItems="center">
                            <LinearProgress
                              variant="determinate"
                              value={usagePercentage}
                              color={status === 'critical' ? 'error' : status === 'warning' ? 'warning' : 'primary'}
                              sx={{ width: 100, mr: 1 }}
                            />
                            <Typography variant="body2">
                              {usagePercentage.toFixed(1)}%
                            </Typography>
                          </Box>
                        </TableCell>
                        <TableCell>
                          <Chip
                            label={status}
                            color={status === 'critical' ? 'error' : status === 'warning' ? 'warning' : 'success'}
                            size="small"
                          />
                        </TableCell>
                      </TableRow>
                    );
                  })}
                </TableBody>
              </Table>
            </TableContainer>
          )}
        </CardContent>
      </Card>

      {/* Resize Storage Dialog */}
      <Dialog
        open={resizeDialogOpen}
        onClose={() => setResizeDialogOpen(false)}
        maxWidth="sm"
        fullWidth
      >
        <DialogTitle>Resize VM Storage</DialogTitle>
        <DialogContent>
          <Box sx={{ mt: 2 }}>
            <Typography variant="body1" gutterBottom>
              Resize storage for VM: <strong>{selectedVm?.name}</strong>
            </Typography>
            <TextField
              fullWidth
              label="New Storage Size (GB)"
              type="number"
              value={newSize}
              onChange={(e) => setNewSize(e.target.value)}
              inputProps={{ min: 1, max: 1000 }}
              sx={{ mt: 2 }}
            />
          </Box>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setResizeDialogOpen(false)}>Cancel</Button>
          <Button
            onClick={handleResizeStorage}
            variant="contained"
            disabled={loading || !newSize}
          >
            Resize Storage
          </Button>
        </DialogActions>
      </Dialog>

      {/* Create Snapshot Dialog */}
      <Dialog
        open={snapshotDialogOpen}
        onClose={() => setSnapshotDialogOpen(false)}
        maxWidth="sm"
        fullWidth
      >
        <DialogTitle>Create VM Snapshot</DialogTitle>
        <DialogContent>
          <Box sx={{ mt: 2 }}>
            <Typography variant="body1" gutterBottom>
              Create snapshot for VM: <strong>{selectedVm?.name}</strong>
            </Typography>
            <TextField
              fullWidth
              label="Snapshot Name"
              value={snapshotName}
              onChange={(e) => setSnapshotName(e.target.value)}
              sx={{ mt: 2 }}
            />
          </Box>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setSnapshotDialogOpen(false)}>Cancel</Button>
          <Button
            onClick={handleCreateSnapshot}
            variant="contained"
            disabled={loading || !snapshotName}
          >
            Create Snapshot
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default StorageManagement;