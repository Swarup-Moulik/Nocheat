from pydantic import BaseModel, EmailStr, ConfigDict
from typing import Optional

class AdminLogin(BaseModel):
    email: EmailStr

class StudentLogin(BaseModel):
    email: EmailStr
    student_roll: str

class InstituteCreate(BaseModel):
    name: str

class InstituteResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    name: str

class UserCreate(BaseModel):
    institute_id: str 
    name: str
    email: EmailStr
    role: str 
    student_roll: Optional[str] = None
    class_id: Optional[str] = None

class UserUpdateClass(BaseModel):
    class_id: str

class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    institute_id: Optional[str] = None
    name: str
    email: str
    role: str
    student_roll: Optional[str] = None
    class_id: Optional[str] = None

class SubjectCreate(BaseModel):
    institute_id: str 
    code: str
    name: str
    class_id: str
    assigned_teacher_id: Optional[str] = None

class SubjectResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    institute_id: str 
    code: str
    name: str
    class_id: str
    assigned_teacher_id: Optional[str] = None

class ClassCreate(BaseModel):
    institute_id: str 
    name: str

class ClassResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    institute_id: str 
    name: str

class ClassAssignmentCreate(BaseModel):
    institute_id: str 
    class_id: str
    subject_id: str
    teacher_id: str

class ClassAssignmentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    institute_id: str 
    class_id: str
    subject_id: str
    teacher_id: str