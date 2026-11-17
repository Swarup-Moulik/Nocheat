from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import delete
from typing import List
from pydantic import BaseModel, EmailStr
from app.models.exam_models import ExamSession, Submission

from app.core.database import get_db
from app.core.websocket import manager
from app.models.exam_models import Exam
from app.models.user_models import User, ClassAssignment, ClassGroup, Subject # <-- New imports
from app.schemas.exam_schemas import ExamCreate, ExamResponse, StudentResult
from app.controllers import teacher_engine

router = APIRouter(tags=["Teacher API"])

# --- TEACHER AUTHENTICATION & DATA ---

class TeacherLogin(BaseModel):
    email: EmailStr

@router.post("/api/teacher/login")
async def teacher_login(payload: TeacherLogin, db: AsyncSession = Depends(get_db)):
    query = select(User).where(User.email == payload.email, User.role == "teacher")
    result = await db.execute(query)
    teacher = result.scalars().first()
    
    if not teacher:
        raise HTTPException(status_code=401, detail="Invalid email or not a Teacher")
        
    return {"id": teacher.id, "name": teacher.name, "institute_id": teacher.institute_id}

@router.get("/api/teacher/{teacher_id}/assignments")
async def get_teacher_assignments(teacher_id: str, db: AsyncSession = Depends(get_db)):
    # 1. Get all assignments for this specific teacher
    query = select(ClassAssignment).where(ClassAssignment.teacher_id == teacher_id)
    result = await db.execute(query)
    assignments = result.scalars().all()
    
    if not assignments:
        return []
        
    # 2. Fetch the readable names for the classes and subjects
    class_ids = [a.class_id for a in assignments]
    sub_ids = [a.subject_id for a in assignments]
    
    classes_res = await db.execute(select(ClassGroup).where(ClassGroup.id.in_(class_ids)))
    subjects_res = await db.execute(select(Subject).where(Subject.id.in_(sub_ids)))
    
    classes_map = {c.id: c.name for c in classes_res.scalars().all()}
    subjects_map = {s.id: f"{s.code} - {s.name}" for s in subjects_res.scalars().all()}
    
    # 3. Build a combined mapping for the Flutter dropdowns
    data = []
    for a in assignments:
        data.append({
            "class_id": a.class_id,
            "class_name": classes_map.get(a.class_id, "Unknown Class"),
            "subject_id": a.subject_id,
            "subject_name": subjects_map.get(a.subject_id, "Unknown Subject")
        })
    return data

@router.post("/api/teacher/exams", response_model=ExamResponse)
async def create_new_exam(payload: ExamCreate, db: AsyncSession = Depends(get_db)):
    new_exam = await teacher_engine.create_exam(db, payload)
    return new_exam

# --- NEW: Get all exams for a specific institute ---
@router.get("/api/teacher/exams", response_model=List[ExamResponse])
async def get_institute_exams(institute_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Exam).where(Exam.institute_id == institute_id))
    return result.scalars().all()

@router.get("/api/teacher/exams/{exam_id}/results", response_model=List[StudentResult])
async def get_results(exam_id: str, db: AsyncSession = Depends(get_db)):
    results = await teacher_engine.get_exam_results(db, exam_id)
    if results is None:
        raise HTTPException(status_code=404, detail="Exam not found")
    return results

@router.get("/api/teacher/{teacher_id}/exams")
async def get_teacher_exams(teacher_id: str, db: AsyncSession = Depends(get_db)):
    query = select(Exam).where(Exam.teacher_id == teacher_id).order_by(Exam.created_at.desc())
    result = await db.execute(query)
    exams = result.scalars().all()
    
    return [
        {
            "id": e.id, 
            "title": e.title, 
            "total_marks": e.total_marks, 
            "created_at": e.created_at,
            "duration_minutes": getattr(e, 'duration_minutes', 60),
            "start_time": e.start_time.isoformat() + "Z" if getattr(e, 'start_time', None) else None,
            "end_time": e.end_time.isoformat() + "Z" if getattr(e, 'end_time', None) else None
        } 
        for e in exams
    ]

@router.delete("/api/teacher/exams/{exam_id}")
async def delete_exam(exam_id: str, db: AsyncSession = Depends(get_db)):
    # 1. Find all sessions linked to this exam
    sessions_res = await db.execute(select(ExamSession).where(ExamSession.exam_id == exam_id))
    sessions = sessions_res.scalars().all()
    session_ids = [s.id for s in sessions]

    # 2. Delete all submissions for those sessions
    if session_ids:
        await db.execute(delete(Submission).where(Submission.session_id.in_(session_ids)))
    
    # 3. Delete the sessions
    await db.execute(delete(ExamSession).where(ExamSession.exam_id == exam_id))
    
    # 4. Finally, delete the exam itself
    result = await db.execute(delete(Exam).where(Exam.id == exam_id))
    await db.commit()
    
    return {"status": "success", "message": "Exam deleted"}

# --- WEBSOCKET ENDPOINTS ---

@router.websocket("/ws/teacher/{exam_id}")
async def teacher_dashboard_endpoint(websocket: WebSocket, exam_id: str):
    await manager.connect(websocket, exam_id)
    try:
        while True:
            # The backend just listens to keep the connection alive
            data = await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(websocket, exam_id)