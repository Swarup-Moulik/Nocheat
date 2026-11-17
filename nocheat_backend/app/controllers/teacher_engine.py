import uuid
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from app.models.exam_models import Exam, ExamSession, Submission
from app.models.user_models import User
from app.schemas.exam_schemas import ExamCreate

async def create_exam(db: AsyncSession, payload: ExamCreate):
    new_exam = Exam(
        id=str(uuid.uuid4()),
        institute_id=payload.institute_id,
        title=payload.title,
        subject_id=payload.subject_id,
        class_id=payload.class_id,
        teacher_id=payload.teacher_id,
        total_marks=payload.total_marks,
        duration_minutes=payload.duration_minutes,
        penalty_seconds=payload.penalty_seconds,
        start_time=payload.start_time.replace(tzinfo=None),
        end_time=payload.end_time.replace(tzinfo=None),
        questions=[q.model_dump() for q in payload.questions] 
    )
    db.add(new_exam)
    await db.commit()
    await db.refresh(new_exam)
    return new_exam

async def get_exam_results(db: AsyncSession, exam_id: str):
    exam_result = await db.execute(select(Exam).where(Exam.id == exam_id))
    exam = exam_result.scalars().first()
    if not exam:
        return None

    # 1. Map questions and correct answers
    answer_key = {q["id"]: {"text": q["text"], "answer": q["correct_answer"], "marks": q.get("marks", 1)} for q in exam.questions}
    
    # 2. Get all sessions for this exam
    sessions_result = await db.execute(select(ExamSession).where(ExamSession.exam_id == exam_id))
    sessions = sessions_result.scalars().all()

    if not sessions:
        return []

    # 3. Get submissions mapped by session
    session_ids = [s.id for s in sessions]
    sub_res = await db.execute(select(Submission).where(Submission.session_id.in_(session_ids)))
    submissions = {sub.session_id: sub for sub in sub_res.scalars().all()}

    # 4. Get student names from the Users table
    student_ids = [s.student_id for s in sessions]
    users_res = await db.execute(select(User).where(User.id.in_(student_ids)))
    users_map = {u.id: u for u in users_res.scalars().all()}

    results = []
    for session in sessions:
        score = 0
        sub = submissions.get(session.id)
        student = users_map.get(session.student_id)
        
        detailed_answers = []
        student_answers = sub.answers if sub and sub.answers else {}
        
        # 5. Compare answers and build the detailed array
        for q_id, q_data in answer_key.items():
            s_ans = student_answers.get(q_id, "Not Answered")
            is_correct = (s_ans == q_data["answer"])
            awarded = q_data["marks"] if is_correct else 0
            score += awarded
            
            detailed_answers.append({
                "question_text": q_data["text"],
                "student_answer": s_ans,
                "correct_answer": q_data["answer"],
                "marks_awarded": awarded,
                "max_marks": q_data["marks"]
            })
        
        results.append({
            "session_id": session.id,
            "student_id": session.student_id,
            "student_name": student.name if student else "Unknown",
            "student_roll": student.student_roll if student else "-",
            "status": session.status,
            "violation_count": session.violation_count,
            "score": score,
            "total_marks": exam.total_marks,
            "detailed_answers": detailed_answers
        })
        
    return results