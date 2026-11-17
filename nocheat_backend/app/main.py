from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from app.core.database import engine, Base
from app.routers import student, teacher, admin

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Automatically generate tables in Neon if they don't exist
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    # Cleanup on shutdown
    await engine.dispose()

app = FastAPI(title="Nocheat Backend Architecture", lifespan=lifespan)

# Allow Flutter apps to communicate with FastAPI
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(student.router)
app.include_router(teacher.router)
app.include_router(admin.router)

@app.get("/health")
async def health_check():
    return {"status": "operational", "layer": "FastAPI + Neon"}