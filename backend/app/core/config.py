from pydantic_settings import BaseSettings
from typing import List
import os

class Settings(BaseSettings):
    # Database
    DATABASE_URL: str = "postgresql://admin:admin123@localhost:5432/datacenter"
    
    # JWT
    JWT_SECRET_KEY: str = "your-secret-key"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    
    # Hetzner API
    HETZNER_API_TOKEN: str = ""
    
    # Slack Integration
    SLACK_WEBHOOK_URL: str = ""
    
    # JIRA Integration
    JIRA_URL: str = ""
    JIRA_USERNAME: str = ""
    JIRA_API_TOKEN: str = ""
    
    # CORS
    CORS_ORIGINS: List[str] = ["http://localhost:3000", "http://localhost:3001"]
    
    # Resource Limits
    MAX_BAREMETALS: int = 200
    MAX_VMS: int = 300
    
    # Default VM Configuration
    DEFAULT_VM_USER: str = "acceldata"
    DEFAULT_SSH_KEY_PATH: str = "/shared/ssh_keys/default_key.pub"
    
    # Monitoring
    PROMETHEUS_RETENTION: str = "30d"
    
    # Redis
    REDIS_URL: str = "redis://localhost:6379/0"
    
    class Config:
        env_file = ".env"

settings = Settings()