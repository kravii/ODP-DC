import React, { useState, useEffect } from 'react';
import { Layout, Menu, Button, Avatar, Dropdown, message } from 'antd';
import { 
  DashboardOutlined, 
  ServerOutlined, 
  CloudServerOutlined, 
  MonitorOutlined, 
  UserOutlined,
  KeyOutlined,
  LogoutOutlined,
  SettingOutlined
} from '@ant-design/icons';
import { Routes, Route, useNavigate, useLocation } from 'react-router-dom';

import Dashboard from './components/Dashboard';
import BaremetalManagement from './components/BaremetalManagement';
import VMManagement from './components/VMManagement';
import Monitoring from './components/Monitoring';
import UserManagement from './components/UserManagement';
import SSHKeyManagement from './components/SSHKeyManagement';
import Login from './components/Login';
import { authService } from './services/auth';

const { Header, Sider, Content } = Layout;

function App() {
  const [collapsed, setCollapsed] = useState(false);
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();
  const location = useLocation();

  useEffect(() => {
    checkAuth();
  }, []);

  const checkAuth = async () => {
    try {
      const token = localStorage.getItem('token');
      if (token) {
        const userData = await authService.getCurrentUser();
        setUser(userData);
        setIsAuthenticated(true);
      }
    } catch (error) {
      console.error('Auth check failed:', error);
      localStorage.removeItem('token');
    } finally {
      setLoading(false);
    }
  };

  const handleLogin = (token, userData) => {
    localStorage.setItem('token', token);
    setUser(userData);
    setIsAuthenticated(true);
    navigate('/');
  };

  const handleLogout = () => {
    localStorage.removeItem('token');
    setUser(null);
    setIsAuthenticated(false);
    navigate('/login');
    message.success('Logged out successfully');
  };

  const menuItems = [
    {
      key: '/',
      icon: <DashboardOutlined />,
      label: 'Dashboard',
    },
    {
      key: '/baremetals',
      icon: <ServerOutlined />,
      label: 'Baremetal Servers',
    },
    {
      key: '/vms',
      icon: <CloudServerOutlined />,
      label: 'Virtual Machines',
    },
    {
      key: '/monitoring',
      icon: <MonitorOutlined />,
      label: 'Monitoring',
    },
    {
      key: '/ssh-keys',
      icon: <KeyOutlined />,
      label: 'SSH Keys',
    },
    ...(user?.role === 'admin' ? [{
      key: '/users',
      icon: <UserOutlined />,
      label: 'User Management',
    }] : []),
  ];

  const userMenuItems = [
    {
      key: 'profile',
      icon: <UserOutlined />,
      label: 'Profile',
    },
    {
      key: 'settings',
      icon: <SettingOutlined />,
      label: 'Settings',
    },
    {
      key: 'logout',
      icon: <LogoutOutlined />,
      label: 'Logout',
      onClick: handleLogout,
    },
  ];

  if (loading) {
    return <div>Loading...</div>;
  }

  if (!isAuthenticated) {
    return <Login onLogin={handleLogin} />;
  }

  return (
    <Layout style={{ minHeight: '100vh' }}>
      <Sider 
        collapsible 
        collapsed={collapsed} 
        onCollapse={setCollapsed}
        theme="light"
      >
        <div style={{ 
          height: 64, 
          display: 'flex', 
          alignItems: 'center', 
          justifyContent: 'center',
          borderBottom: '1px solid #f0f0f0'
        }}>
          <h2 style={{ 
            color: '#1890ff', 
            margin: 0,
            fontSize: collapsed ? '16px' : '20px'
          }}>
            {collapsed ? 'DC' : 'Data Center'}
          </h2>
        </div>
        <Menu
          mode="inline"
          selectedKeys={[location.pathname]}
          items={menuItems}
          onClick={({ key }) => navigate(key)}
        />
      </Sider>
      <Layout>
        <Header style={{ 
          background: '#fff', 
          padding: '0 24px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          boxShadow: '0 2px 8px rgba(0, 0, 0, 0.1)'
        }}>
          <h1 style={{ margin: 0, fontSize: '20px', fontWeight: 600 }}>
            Data Center Management System
          </h1>
          <Dropdown
            menu={{ items: userMenuItems }}
            placement="bottomRight"
          >
            <Button type="text" style={{ display: 'flex', alignItems: 'center' }}>
              <Avatar icon={<UserOutlined />} style={{ marginRight: 8 }} />
              {user?.username}
            </Button>
          </Dropdown>
        </Header>
        <Content style={{ padding: '24px' }}>
          <Routes>
            <Route path="/" element={<Dashboard />} />
            <Route path="/baremetals" element={<BaremetalManagement />} />
            <Route path="/vms" element={<VMManagement />} />
            <Route path="/monitoring" element={<Monitoring />} />
            <Route path="/ssh-keys" element={<SSHKeyManagement />} />
            {user?.role === 'admin' && (
              <Route path="/users" element={<UserManagement />} />
            )}
          </Routes>
        </Content>
      </Layout>
    </Layout>
  );
}

export default App;