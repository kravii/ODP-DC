from pydantic import BaseModel
from typing import Optional

class SSHKeyCreate(BaseModel):
    name: str
    public_key: str
    private_key: Optional[str] = None
    is_default: bool = False

class SSHKeyUpdate(BaseModel):
    name: Optional[str] = None
    is_default: Optional[bool] = None

class SSHKeyResponse(BaseModel):
    id: str
    name: str
    public_key: str
    is_default: bool
    created_by: Optional[str] = None
    created_at: str

    class Config:
        from_attributes = True