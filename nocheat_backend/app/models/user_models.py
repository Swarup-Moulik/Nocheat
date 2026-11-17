import uuid
import enum
from sqlalchemy import Column, String, Enum
from app.core.database import Base

# --- NEW MULTI-TENANT TABLE ---
class Institute(Base):
    __tablename__ = "institutes"
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String, unique=True, index=True, nullable=False)

class UserRole(str, enum.Enum):
    admin = "admin"
    teacher = "teacher"
    student = "student"

class User(Base):
    __tablename__ = "users"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    institute_id = Column(String, index=True, nullable=True) # Tenant ID
    name = Column(String, nullable=False)
    email = Column(String, unique=True, index=True, nullable=False)
    role = Column(Enum(UserRole), default=UserRole.student, nullable=False)
    student_roll = Column(String, nullable=True) 
    class_id = Column(String, index=True, nullable=True) 

class Subject(Base):
    __tablename__ = "subjects"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    institute_id = Column(String, index=True, nullable=True) # Tenant ID
    code = Column(String, index=True, nullable=False) 
    name = Column(String, nullable=False)
    assigned_teacher_id = Column(String, nullable=True) 
    class_id = Column(String, index=True, nullable=True) 

class ClassGroup(Base):
    __tablename__ = "classes"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    institute_id = Column(String, index=True, nullable=True) # Tenant ID
    name = Column(String, index=True, nullable=False)

class ClassAssignment(Base):
    __tablename__ = "class_assignments"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    institute_id = Column(String, index=True, nullable=True) # Tenant ID
    class_id = Column(String, index=True, nullable=False)
    subject_id = Column(String, index=True, nullable=False)
    teacher_id = Column(String, index=True, nullable=False)