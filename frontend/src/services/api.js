import axios from 'axios';

const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:8000';

const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Add token to requests
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Handle token expiration
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem('token');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

export const apiService = {
  // Baremetal endpoints
  baremetals: {
    getAll: () => api.get('/api/baremetals'),
    getById: (id) => api.get(`/api/baremetals/${id}`),
    create: (data) => api.post('/api/baremetals', data),
    update: (id, data) => api.put(`/api/baremetals/${id}`, data),
    delete: (id) => api.delete(`/api/baremetals/${id}`),
    getResourcePool: () => api.get('/api/baremetals/pool/resources'),
  },

  // VM endpoints
  vms: {
    getAll: () => api.get('/api/vms'),
    getById: (id) => api.get(`/api/vms/${id}`),
    create: (data) => api.post('/api/vms', data),
    update: (id, data) => api.put(`/api/vms/${id}`, data),
    delete: (id) => api.delete(`/api/vms/${id}`),
    start: (id) => api.post(`/api/vms/${id}/start`),
    stop: (id) => api.post(`/api/vms/${id}/stop`),
    getImages: () => api.get('/api/vms/images'),
  },

  // Monitoring endpoints
  monitoring: {
    getHealth: () => api.get('/api/monitoring/health'),
    getMetrics: (params) => api.get('/api/monitoring/metrics', { params }),
    getAlerts: (params) => api.get('/api/monitoring/alerts', { params }),
    resolveAlert: (id) => api.post(`/api/monitoring/alerts/${id}/resolve`),
    getNotifications: (params) => api.get('/api/monitoring/notifications', { params }),
    getUtilization: () => api.get('/api/monitoring/utilization'),
  },

  // User endpoints
  users: {
    getAll: () => api.get('/api/users'),
    getById: (id) => api.get(`/api/users/${id}`),
    create: (data) => api.post('/api/users', data),
    update: (id, data) => api.put(`/api/users/${id}`, data),
    delete: (id) => api.delete(`/api/users/${id}`),
  },

  // SSH Key endpoints
  ssh: {
    getAll: () => api.get('/api/ssh'),
    getById: (id) => api.get(`/api/ssh/${id}`),
    create: (data) => api.post('/api/ssh', data),
    update: (id, data) => api.put(`/api/ssh/${id}`, data),
    delete: (id) => api.delete(`/api/ssh/${id}`),
  },
};