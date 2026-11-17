import uuid
import datetime
from sqlalchemy import Column, String, Integer, DateTime, JSON
from app.core.database import Base

class Exam(Base):
    __tablename__ = "exams"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    institute_id = Column(String, index=True, nullable=True) 
    title = Column(String, nullable=False)
    subject_id = Column(String, index=True)
    class_id = Column(String, index=True)
    teacher_id = Column(String, index=True)
    total_marks = Column(Integer, default=0) 
    questions = Column(JSON, nullable=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    duration_minutes = Column(Integer, default=60)
    penalty_seconds = Column(Integer, default=60)
    start_time = Column(DateTime, nullable=True)
    end_time = Column(DateTime, nullable=True)

class ExamSession(Base):
    __tablename__ = "exam_sessions"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    exam_id = Column(String, index=True)
    student_id = Column(String, index=True)
    status = Column(String, default="active") 
    violation_count = Column(Integer, default=0)
    last_violation_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

class Submission(Base):
    __tablename__ = "submissions"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    session_id = Column(String, index=True)
    student_id = Column(String)
    answers = Column(JSON)
    submitted_at = Column(DateTime, default=datetime.datetime.utcnow)