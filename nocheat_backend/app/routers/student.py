from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from typing import List

from app.core.database import get_db
from app.core.websocket import manager
from app.schemas.exam_schemas import ViolationCreate, SubmissionCreate, JoinExamRequest
from app.schemas.user_schemas import StudentLogin
from app.models.user_models import User, ClassGroup, ClassAssignment, Subject
from app.models.exam_models import ExamSession, Submission, Exam
from app.controllers import student_engine

router = APIRouter(prefix="/api/student", tags=["Student API"])

# --- AUTHENTICATION & DASHBOARD ---

@router.post("/login")
async def student_login(payload: StudentLogin, db: AsyncSession = Depends(get_db)):
    query = select(User).where(
        User.email == payload.email, 
        User.student_roll == payload.student_roll, 
        User.role == "student"
    )
    result = await db.execute(query)
    student = result.scalars().first()
    
    if not student:
        raise HTTPException(status_code=401, detail="Invalid Email or Student ID")
        
    class_query = select(ClassGroup).where(ClassGroup.id == student.class_id)
    class_res = await db.execute(class_query)
    class_grp = class_res.scalars().first()

    return {
        "id": student.id,
        "name": student.name,
        "institute_id": student.institute_id,
        "class_id": student.class_id,
        "class_name": class_grp.name if class_grp else "Unassigned",
        "student_roll": student.student_roll
    }

@router.get("/{student_id}/subjects")
async def get_student_subjects(student_id: str, db: AsyncSession = Depends(get_db)):
    user_res = await db.execute(select(User).where(User.id == student_id))
    student = user_res.scalars().first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    assign_query = select(ClassAssignment).where(ClassAssignment.class_id == student.class_id)
    assign_res = await db.execute(assign_query)
    subject_ids = [a.subject_id for a in assign_res.scalars().all()]

    sub_query = select(Subject).where(Subject.id.in_(subject_ids))
    sub_res = await db.execute(sub_query)
    subjects = sub_res.scalars().all()

    return [{"id": s.id, "code": s.code, "name": s.name} for s in subjects]

@router.get("/{student_id}/subjects/{subject_id}/exams")
async def get_student_exams(student_id: str, subject_id: str, db: AsyncSession = Depends(get_db)):
    user_res = await db.execute(select(User).where(User.id == student_id))
    student = user_res.scalars().first()
    
    exam_query = select(Exam).where(Exam.subject_id == subject_id, Exam.class_id == student.class_id)
    exam_res = await db.execute(exam_query)
    exams = exam_res.scalars().all()

    results = []
    for exam in exams:
        ses_query = select(ExamSession).where(
            ExamSession.exam_id == exam.id, 
            ExamSession.student_id == student_id
        ).order_by(ExamSession.created_at.desc())
        
        ses_res = await db.execute(ses_query)
        session = ses_res.scalars().first()

        score = None
        status = "pending"
        
        # AUTO-GRADING LOGIC
        if session:
            status = session.status
            if status == "submitted":
                sub_query = select(Submission).where(Submission.session_id == session.id)
                sub_res = await db.execute(sub_query)
                submission = sub_res.scalars().first()
                
                if submission and submission.answers:
                    score = 0
                    answer_key = {q["id"]: {"answer": q["correct_answer"], "marks": q.get("marks", 1)} for q in exam.questions}
                    for q_id, q_data in answer_key.items():
                        if submission.answers.get(q_id) == q_data["answer"]:
                            score += q_data["marks"]

        # Add the new timing fields into the response
        results.append({
            "id": exam.id,
            "title": exam.title,
            "total_marks": exam.total_marks,
            "duration_minutes": getattr(exam, 'duration_minutes', 60),
            "start_time": exam.start_time.isoformat() + "Z" if getattr(exam, 'start_time', None) else None,
            "end_time": exam.end_time.isoformat() + "Z" if getattr(exam, 'end_time', None) else None,
            "status": status,
            "score": score
        })
    return results

# --- EXAM EXECUTION ---

@router.post("/join")
async def join_exam(payload: JoinExamRequest, db: AsyncSession = Depends(get_db)):
    session = await student_engine.start_exam_session(db, payload)
    return {"session_id": session.id, "status": "active"}

@router.get("/exams/{exam_id}")
async def get_exam_details(exam_id: str, db: AsyncSession = Depends(get_db)):
    exam_res = await db.execute(select(Exam).where(Exam.id == exam_id))
    exam = exam_res.scalars().first()
    
    if not exam:
        raise HTTPException(status_code=404, detail="Exam not found")
        
    safe_questions = []
    for q in exam.questions:
        safe_questions.append({
            "id": q["id"],
            "text": q["text"],
            "options": q["options"]
        })
        
    return {
        "id": exam.id,
        "title": exam.title,
        "duration_minutes": getattr(exam, 'duration_minutes', 60), 
        "penalty_seconds": getattr(exam, 'penalty_seconds', 60),
        "questions": safe_questions
    }

@router.post("/violation")
async def report_violation(payload: ViolationCreate, db: AsyncSession = Depends(get_db)):
    updated_session = await student_engine.log_violation(db, payload)
    if not updated_session:
        raise HTTPException(status_code=404, detail="Session not found")

    alert_payload = {
        "event": "violation",
        "student_id": payload.student_id,
        "violation_count": updated_session.violation_count,
        "timestamp": payload.timestamp.isoformat()
    }
    await manager.broadcast(updated_session.exam_id, alert_payload)
    return {"status": "violation_logged", "count": updated_session.violation_count}

@router.post("/submit")
async def submit_exam(payload: SubmissionCreate, db: AsyncSession = Depends(get_db)):
    await student_engine.finalize_exam(db, payload)
    return {"status": "success", "message": "Exam secured and submitted."}