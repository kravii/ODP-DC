"""
Database configuration and session management
"""

from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
import os
from typing import Generator

# Database URL from environment variables
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    f"postgresql://{os.getenv('POSTGRES_USER', 'hetzner_dc_user')}:"
    f"{os.getenv('POSTGRES_PASSWORD', 'secure_password_here')}@"
    f"{os.getenv('POSTGRES_HOST', 'postgresql-service')}:"
    f"{os.getenv('POSTGRES_PORT', '5432')}/"
    f"{os.getenv('POSTGRES_DB', 'hetzner_dc')}"
)

# Create SQLAlchemy engine
engine = create_engine(
    DATABASE_URL,
    poolclass=StaticPool,
    pool_pre_ping=True,
    pool_recycle=300,
    echo=os.getenv("DEBUG", "false").lower() == "true"
)

# Create SessionLocal class
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Create Base class for models
Base = declarative_base()

def get_db() -> Generator:
    """
    Dependency to get database session
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def init_db():
    """
    Initialize database tables
    """
    from .models import Base
    Base.metadata.create_all(bind=engine)

def check_db_connection():
    """
    Check database connection
    """
    try:
        db = SessionLocal()
        db.execute("SELECT 1")
        db.close()
        return True
    except Exception as e:
        print(f"Database connection failed: {e}")
        return False