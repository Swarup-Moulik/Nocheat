import uuid
from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from datetime import datetime
from app.models.exam_models import ExamSession, Submission, Exam
from app.models.user_models import User
from app.schemas.exam_schemas import ViolationCreate, SubmissionCreate, JoinExamRequest

async def start_exam_session(db: AsyncSession, payload: JoinExamRequest):
    exam_res = await db.execute(select(Exam).where(
        Exam.id == payload.exam_id,
        Exam.institute_id == payload.institute_id
    ))
    exam = exam_res.scalars().first()
    if not exam:
        raise HTTPException(status_code=404, detail="Exam not found in this institute")

    now = datetime.utcnow()
    if exam.start_time and now < exam.start_time:
        raise HTTPException(status_code=403, detail="This exam has not started yet.")
    if exam.end_time and now > exam.end_time:
        raise HTTPException(status_code=403, detail="This exam has already ended.")

    user_res = await db.execute(select(User).where(
        User.id == payload.student_id,
        User.institute_id == payload.institute_id
    ))
    student = user_res.scalars().first()
    
    if not student or student.role != "student":
        raise HTTPException(status_code=403, detail="Only students can join exams")
    
    # --- NEW: Check for existing session ---
    existing_res = await db.execute(select(ExamSession).where(
        ExamSession.exam_id == payload.exam_id,
        ExamSession.student_id == payload.student_id
    ))
    existing_session = existing_res.scalars().first()

    if existing_session:
        if existing_session.status == "submitted":
            raise HTTPException(status_code=400, detail="You have already completed this exam.")
        # If it's active or frozen, return the existing session so they can resume
        return existing_session
    
    # --- Create New Session ---
    new_session = ExamSession(
        id=str(uuid.uuid4()),
        exam_id=payload.exam_id,
        student_id=payload.student_id,
        status="active",
        violation_count=0
    )
    db.add(new_session)
    await db.commit()
    await db.refresh(new_session)
    return new_session

async def log_violation(db: AsyncSession, payload: ViolationCreate):
    result = await db.execute(select(ExamSession).where(ExamSession.id == payload.session_id))
    session = result.scalars().first()
    
    if session:
        session.violation_count += 1
        session.last_violation_at = payload.timestamp.replace(tzinfo=None)
        session.status = "frozen"
        await db.commit()
        await db.refresh(session)
        return session
    return None

async def finalize_exam(db: AsyncSession, payload: SubmissionCreate):
    result = await db.execute(select(ExamSession).where(ExamSession.id == payload.session_id))
    session = result.scalars().first()
    
    if session:
        session.status = "submitted"
    
    submission = Submission(
        id=str(uuid.uuid4()), # Explicit ID generation
        session_id=payload.session_id,
        student_id=payload.student_id,
        answers=payload.answers
    )
    
    db.add(submission)
    await db.commit()
    return submission