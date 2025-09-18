import React, { useState, useEffect } from 'react';
import {
  Card,
  CardContent,
  Typography,
  Button,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
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
  Grid,
  Alert,
  CircularProgress
} from '@mui/material';
import {
  Add as AddIcon,
  Edit as EditIcon,
  Delete as DeleteIcon,
  PlayArrow as PlayIcon,
  Stop as StopIcon,
  Refresh as RefreshIcon,
  Visibility as ViewIcon
} from '@mui/icons-material';
import { apiService } from '../services/api';

const VMManagement = () => {
  const [vms, setVms] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [createDialogOpen, setCreateDialogOpen] = useState(false);
  const [editDialogOpen, setEditDialogOpen] = useState(false);
  const [selectedVm, setSelectedVm] = useState(null);
  const [vmForm, setVmForm] = useState({
    name: '',
    image: 'ubuntu22',
    server_type: 'cx21',
    cpu: 2,
    memory: 4,
    storage: 40,
    namespace: 'default'
  });

  const osImages = [
    { value: 'centos7', label: 'CentOS 7' },
    { value: 'rhel7', label: 'RHEL 7' },
    { value: 'rhel8', label: 'RHEL 8' },
    { value: 'rhel9', label: 'RHEL 9' },
    { value: 'rockylinux9', label: 'Rocky Linux 9' },
    { value: 'ubuntu20', label: 'Ubuntu 20.04' },
    { value: 'ubuntu22', label: 'Ubuntu 22.04' },
    { value: 'ubuntu24', label: 'Ubuntu 24.04' },
    { value: 'oel8', label: 'Oracle Enterprise Linux 8' }
  ];

  const serverTypes = [
    { value: 'cx11', label: 'CX11 (1 CPU, 4GB RAM)' },
    { value: 'cx21', label: 'CX21 (2 CPU, 8GB RAM)' },
    { value: 'cx31', label: 'CX31 (2 CPU, 8GB RAM)' },
    { value: 'cx41', label: 'CX41 (4 CPU, 16GB RAM)' },
    { value: 'cx51', label: 'CX51 (8 CPU, 32GB RAM)' }
  ];

  useEffect(() => {
    fetchVMs();
  }, []);

  const fetchVMs = async () => {
    setLoading(true);
    try {
      const data = await apiService.getVMs();
      setVms(data);
      setError(null);
    } catch (err) {
      setError('Failed to fetch VMs: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleCreateVM = async () => {
    try {
      setLoading(true);
      await apiService.createVM(vmForm);
      setCreateDialogOpen(false);
      setVmForm({
        name: '',
        image: 'ubuntu22',
        server_type: 'cx21',
        cpu: 2,
        memory: 4,
        storage: 40,
        namespace: 'default'
      });
      await fetchVMs();
    } catch (err) {
      setError('Failed to create VM: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleUpdateVM = async () => {
    try {
      setLoading(true);
      await apiService.updateVM(selectedVm.id, vmForm);
      setEditDialogOpen(false);
      setSelectedVm(null);
      await fetchVMs();
    } catch (err) {
      setError('Failed to update VM: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleDeleteVM = async (vmId) => {
    if (window.confirm('Are you sure you want to delete this VM?')) {
      try {
        setLoading(true);
        await apiService.deleteVM(vmId);
        await fetchVMs();
      } catch (err) {
        setError('Failed to delete VM: ' + err.message);
      } finally {
        setLoading(false);
      }
    }
  };

  const handleStartVM = async (vmId) => {
    try {
      setLoading(true);
      await apiService.startVM(vmId);
      await fetchVMs();
    } catch (err) {
      setError('Failed to start VM: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleStopVM = async (vmId) => {
    try {
      setLoading(true);
      await apiService.stopVM(vmId);
      await fetchVMs();
    } catch (err) {
      setError('Failed to stop VM: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  const getStatusColor = (status) => {
    switch (status) {
      case 'running': return 'success';
      case 'stopped': return 'default';
      case 'creating': return 'warning';
      case 'error': return 'error';
      default: return 'default';
    }
  };

  const openEditDialog = (vm) => {
    setSelectedVm(vm);
    setVmForm({
      name: vm.name,
      image: vm.image,
      server_type: vm.server_type,
      cpu: vm.cpu,
      memory: vm.memory,
      storage: vm.storage,
      namespace: vm.namespace
    });
    setEditDialogOpen(true);
  };

  return (
    <Box>
      <Box display="flex" justifyContent="space-between" alignItems="center" mb={3}>
        <Typography variant="h4" component="h1">
          VM Management
        </Typography>
        <Button
          variant="contained"
          startIcon={<AddIcon />}
          onClick={() => setCreateDialogOpen(true)}
        >
          Create VM
        </Button>
      </Box>

      {error && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      <Card>
        <CardContent>
          <Box display="flex" justifyContent="space-between" alignItems="center" mb={2}>
            <Typography variant="h6">Virtual Machines</Typography>
            <IconButton onClick={fetchVMs} disabled={loading}>
              <RefreshIcon />
            </IconButton>
          </Box>

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
                    <TableCell>Image</TableCell>
                    <TableCell>Server Type</TableCell>
                    <TableCell>Resources</TableCell>
                    <TableCell>IP Address</TableCell>
                    <TableCell>Status</TableCell>
                    <TableCell>Namespace</TableCell>
                    <TableCell>Actions</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {vms.map((vm) => (
                    <TableRow key={vm.id}>
                      <TableCell>{vm.name}</TableCell>
                      <TableCell>{vm.image}</TableCell>
                      <TableCell>{vm.server_type}</TableCell>
                      <TableCell>
                        {vm.cpu} CPU, {vm.memory}GB RAM, {vm.storage}GB Storage
                      </TableCell>
                      <TableCell>{vm.ip_address || 'N/A'}</TableCell>
                      <TableCell>
                        <Chip
                          label={vm.status}
                          color={getStatusColor(vm.status)}
                          size="small"
                        />
                      </TableCell>
                      <TableCell>{vm.namespace}</TableCell>
                      <TableCell>
                        <Tooltip title="View Details">
                          <IconButton size="small">
                            <ViewIcon />
                          </IconButton>
                        </Tooltip>
                        <Tooltip title="Edit VM">
                          <IconButton
                            size="small"
                            onClick={() => openEditDialog(vm)}
                          >
                            <EditIcon />
                          </IconButton>
                        </Tooltip>
                        {vm.status === 'running' ? (
                          <Tooltip title="Stop VM">
                            <IconButton
                              size="small"
                              onClick={() => handleStopVM(vm.id)}
                            >
                              <StopIcon />
                            </IconButton>
                          </Tooltip>
                        ) : (
                          <Tooltip title="Start VM">
                            <IconButton
                              size="small"
                              onClick={() => handleStartVM(vm.id)}
                            >
                              <PlayIcon />
                            </IconButton>
                          </Tooltip>
                        )}
                        <Tooltip title="Delete VM">
                          <IconButton
                            size="small"
                            onClick={() => handleDeleteVM(vm.id)}
                            color="error"
                          >
                            <DeleteIcon />
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

      {/* Create VM Dialog */}
      <Dialog
        open={createDialogOpen}
        onClose={() => setCreateDialogOpen(false)}
        maxWidth="md"
        fullWidth
      >
        <DialogTitle>Create New VM</DialogTitle>
        <DialogContent>
          <Grid container spacing={2} sx={{ mt: 1 }}>
            <Grid item xs={12}>
              <TextField
                fullWidth
                label="VM Name"
                value={vmForm.name}
                onChange={(e) => setVmForm({ ...vmForm, name: e.target.value })}
                required
              />
            </Grid>
            <Grid item xs={12} sm={6}>
              <FormControl fullWidth>
                <InputLabel>OS Image</InputLabel>
                <Select
                  value={vmForm.image}
                  onChange={(e) => setVmForm({ ...vmForm, image: e.target.value })}
                >
                  {osImages.map((image) => (
                    <MenuItem key={image.value} value={image.value}>
                      {image.label}
                    </MenuItem>
                  ))}
                </Select>
              </FormControl>
            </Grid>
            <Grid item xs={12} sm={6}>
              <FormControl fullWidth>
                <InputLabel>Server Type</InputLabel>
                <Select
                  value={vmForm.server_type}
                  onChange={(e) => setVmForm({ ...vmForm, server_type: e.target.value })}
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
                value={vmForm.cpu}
                onChange={(e) => setVmForm({ ...vmForm, cpu: parseInt(e.target.value) })}
                inputProps={{ min: 1, max: 32 }}
              />
            </Grid>
            <Grid item xs={12} sm={4}>
              <TextField
                fullWidth
                label="Memory (GB)"
                type="number"
                value={vmForm.memory}
                onChange={(e) => setVmForm({ ...vmForm, memory: parseInt(e.target.value) })}
                inputProps={{ min: 1, max: 128 }}
              />
            </Grid>
            <Grid item xs={12} sm={4}>
              <TextField
                fullWidth
                label="Storage (GB)"
                type="number"
                value={vmForm.storage}
                onChange={(e) => setVmForm({ ...vmForm, storage: parseInt(e.target.value) })}
                inputProps={{ min: 10, max: 1000 }}
              />
            </Grid>
            <Grid item xs={12}>
              <TextField
                fullWidth
                label="Namespace"
                value={vmForm.namespace}
                onChange={(e) => setVmForm({ ...vmForm, namespace: e.target.value })}
                required
              />
            </Grid>
          </Grid>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setCreateDialogOpen(false)}>Cancel</Button>
          <Button
            onClick={handleCreateVM}
            variant="contained"
            disabled={loading || !vmForm.name}
          >
            Create VM
          </Button>
        </DialogActions>
      </Dialog>

      {/* Edit VM Dialog */}
      <Dialog
        open={editDialogOpen}
        onClose={() => setEditDialogOpen(false)}
        maxWidth="md"
        fullWidth
      >
        <DialogTitle>Edit VM Resources</DialogTitle>
        <DialogContent>
          <Grid container spacing={2} sx={{ mt: 1 }}>
            <Grid item xs={12}>
              <TextField
                fullWidth
                label="VM Name"
                value={vmForm.name}
                disabled
              />
            </Grid>
            <Grid item xs={12} sm={4}>
              <TextField
                fullWidth
                label="CPU Cores"
                type="number"
                value={vmForm.cpu}
                onChange={(e) => setVmForm({ ...vmForm, cpu: parseInt(e.target.value) })}
                inputProps={{ min: 1, max: 32 }}
              />
            </Grid>
            <Grid item xs={12} sm={4}>
              <TextField
                fullWidth
                label="Memory (GB)"
                type="number"
                value={vmForm.memory}
                onChange={(e) => setVmForm({ ...vmForm, memory: parseInt(e.target.value) })}
                inputProps={{ min: 1, max: 128 }}
              />
            </Grid>
            <Grid item xs={12} sm={4}>
              <TextField
                fullWidth
                label="Storage (GB)"
                type="number"
                value={vmForm.storage}
                onChange={(e) => setVmForm({ ...vmForm, storage: parseInt(e.target.value) })}
                inputProps={{ min: 10, max: 1000 }}
              />
            </Grid>
          </Grid>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setEditDialogOpen(false)}>Cancel</Button>
          <Button
            onClick={handleUpdateVM}
            variant="contained"
            disabled={loading}
          >
            Update VM
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default VMManagement;