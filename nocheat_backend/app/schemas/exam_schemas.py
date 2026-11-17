from pydantic import BaseModel, ConfigDict
from typing import Dict, Any, List
from datetime import datetime

# --- STUDENT SCHEMAS ---
class JoinExamRequest(BaseModel):
    institute_id: str # <-- Added
    student_id: str
    exam_id: str

class ViolationCreate(BaseModel):
    session_id: str
    student_id: str
    event_type: str
    timestamp: datetime

class SubmissionCreate(BaseModel):
    session_id: str
    student_id: str
    answers: Dict[str, Any]
    client_submission_time: datetime

# --- TEACHER SCHEMAS ---
class QuestionSchema(BaseModel):
    id: str
    text: str
    options: List[str]
    correct_answer: str
    marks: int 

class ExamCreate(BaseModel):
    institute_id: str 
    title: str
    subject_id: str
    class_id: str
    teacher_id: str
    total_marks: int 
    duration_minutes: int 
    penalty_seconds: int   
    start_time: datetime   
    end_time: datetime
    questions: List[QuestionSchema]

class ExamResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    institute_id: str # <-- Added
    title: str
    total_marks: int

class DetailedAnswer(BaseModel):
    question_text: str
    student_answer: str
    correct_answer: str
    marks_awarded: int
    max_marks: int

class StudentResult(BaseModel):
    session_id: str
    student_id: str
    student_name: str 
    student_roll: str 
    status: str
    violation_count: int
    score: int
    total_marks: int 
    detailed_answers: List[DetailedAnswer]