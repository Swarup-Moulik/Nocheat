from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from typing import List
from app.core.database import get_db 
from app.models.user_models import User, Subject, ClassGroup, ClassAssignment, UserRole, Institute
from app.schemas.user_schemas import (
    UserCreate, UserResponse, SubjectCreate, SubjectResponse, 
    ClassCreate, ClassResponse, ClassAssignmentCreate, UserUpdateClass,
    ClassAssignmentResponse, InstituteCreate, InstituteResponse, AdminLogin
)

router = APIRouter(prefix="/api/admin", tags=["Admin Operations"])

# --- AUTHENTICATION (NEW) ---

@router.post("/login", response_model=UserResponse)
async def admin_login(payload: AdminLogin, db: AsyncSession = Depends(get_db)):
    query = select(User).where(User.email == payload.email, User.role == "admin")
    result = await db.execute(query)
    admin_user = result.scalars().first()
    
    if not admin_user:
        raise HTTPException(status_code=401, detail="Invalid Admin Email or not an Admin")
        
    return admin_user

# --- INSTITUTE MANAGEMENT ---

@router.post("/institutes", response_model=InstituteResponse)
async def create_institute(payload: InstituteCreate, db: AsyncSession = Depends(get_db)):
    new_inst = Institute(name=payload.name)
    db.add(new_inst)
    await db.commit()
    await db.refresh(new_inst)
    return new_inst

@router.get("/institutes", response_model=List[InstituteResponse])
async def get_institutes(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Institute))
    return result.scalars().all()

# --- USER MANAGEMENT ---

@router.post("/users", response_model=UserResponse)
async def create_user(payload: UserCreate, db: AsyncSession = Depends(get_db)):
    # 1. Block admin creation via API
    if payload.role == "admin":
        raise HTTPException(status_code=403, detail="Admins can only be created via the database directly.")

    result = await db.execute(select(User).where(User.email == payload.email))
    if result.scalars().first():
        raise HTTPException(status_code=400, detail="User with this email already exists")

    new_user = User(
        institute_id=payload.institute_id,
        name=payload.name, 
        email=payload.email, 
        role=UserRole(payload.role),
        student_roll=payload.student_roll,
        class_id=payload.class_id
    )
    
    db.add(new_user)
    await db.commit()
    await db.refresh(new_user)
    return new_user

@router.get("/users", response_model=List[UserResponse])
async def get_users(institute_id: str, db: AsyncSession = Depends(get_db)): 
    # 2. Hide admins from the returned list
    result = await db.execute(
        select(User).where(
            User.institute_id == institute_id,
            User.role != "admin" # <-- Added filter
        )
    )
    return result.scalars().all()

@router.delete("/users/{user_id}")
async def delete_user(user_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalars().first()
    if user:
        await db.delete(user)
        await db.commit()
    return {"status": "success"}

@router.patch("/users/{user_id}/class")
async def update_user_class(user_id: str, payload: UserUpdateClass, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalars().first()
    
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
        
    user.class_id = payload.class_id
    await db.commit()
    
    return {"status": "success", "message": "Class updated successfully"}

# --- SUBJECT MANAGEMENT ---

@router.post("/subjects", response_model=SubjectResponse)
async def create_subject(payload: SubjectCreate, db: AsyncSession = Depends(get_db)):
    query = select(Subject).where(Subject.institute_id == payload.institute_id, Subject.code == payload.code)
    result = await db.execute(query)
    if result.scalars().first():
        raise HTTPException(status_code=400, detail="Subject code already exists in this institute")

    new_subject = Subject(
        institute_id=payload.institute_id, 
        code=payload.code, 
        name=payload.name, 
        class_id=payload.class_id, 
        assigned_teacher_id=payload.assigned_teacher_id
    )
    db.add(new_subject)
    await db.commit()
    await db.refresh(new_subject)
    return new_subject

@router.get("/subjects", response_model=List[SubjectResponse])
async def get_subjects(institute_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Subject).where(Subject.institute_id == institute_id))
    return result.scalars().all()

@router.delete("/subjects/{subject_id}")
async def delete_subject(subject_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Subject).where(Subject.id == subject_id))
    subject = result.scalars().first()
    if subject:
        await db.delete(subject)
        await db.commit()
    return {"status": "success"}

# --- CLASS MANAGEMENT ---

@router.post("/classes", response_model=ClassResponse)
async def create_class(payload: ClassCreate, db: AsyncSession = Depends(get_db)):
    query = select(ClassGroup).where(ClassGroup.institute_id == payload.institute_id, ClassGroup.name == payload.name)
    result = await db.execute(query)
    if result.scalars().first():
        raise HTTPException(status_code=400, detail="Class name already exists in this institute")

    new_class = ClassGroup(institute_id=payload.institute_id, name=payload.name)
    db.add(new_class)
    await db.commit()
    await db.refresh(new_class)
    return new_class

@router.get("/classes", response_model=List[ClassResponse])
async def get_classes(institute_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(ClassGroup).where(ClassGroup.institute_id == institute_id))
    return result.scalars().all()

@router.delete("/classes/{class_id}")
async def delete_class(class_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(ClassGroup).where(ClassGroup.id == class_id))
    class_grp = result.scalars().first()
    if class_grp:
        await db.delete(class_grp)
        await db.commit()
    return {"status": "success"}

# --- ASSIGNMENT MANAGEMENT ---

@router.post("/assignments", response_model=ClassAssignmentResponse)
async def assign_teacher(payload: ClassAssignmentCreate, db: AsyncSession = Depends(get_db)):
    query = select(ClassAssignment).where(
        ClassAssignment.institute_id == payload.institute_id,
        ClassAssignment.class_id == payload.class_id,
        ClassAssignment.subject_id == payload.subject_id,
        ClassAssignment.teacher_id == payload.teacher_id
    )
    result = await db.execute(query)
    if result.scalars().first():
        raise HTTPException(status_code=400, detail="Assignment already exists")

    new_assignment = ClassAssignment(
        institute_id=payload.institute_id,
        class_id=payload.class_id,
        subject_id=payload.subject_id,
        teacher_id=payload.teacher_id
    )
    db.add(new_assignment)
    await db.commit()
    await db.refresh(new_assignment)
    return new_assignment

@router.get("/assignments", response_model=List[ClassAssignmentResponse])
async def get_assignments(institute_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(ClassAssignment).where(ClassAssignment.institute_id == institute_id))
    return result.scalars().all()

@router.delete("/assignments/{assignment_id}")
async def delete_assignment(assignment_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(ClassAssignment).where(ClassAssignment.id == assignment_id))
    assignment = result.scalars().first()
    if assignment:
        await db.delete(assignment)
        await db.commit()
    return {"status": "success"}