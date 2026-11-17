import os
from dotenv import load_dotenv
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.orm import declarative_base

load_dotenv()

raw_db_url = os.getenv("NEON_DATABASE_URL")
if not raw_db_url:
    raise ValueError("NEON_DATABASE_URL environment variable is not set")

if "?" in raw_db_url:
    raw_db_url = raw_db_url.split("?")[0]

if raw_db_url.startswith("postgres://"):
    ASYNC_DB_URL = raw_db_url.replace("postgres://", "postgresql+asyncpg://", 1)
elif raw_db_url.startswith("postgresql://"):
    ASYNC_DB_URL = raw_db_url.replace("postgresql://", "postgresql+asyncpg://", 1)
else:
    ASYNC_DB_URL = raw_db_url

engine = create_async_engine(
    ASYNC_DB_URL, 
    echo=True, 
    connect_args={
        "ssl": "require",
        "statement_cache_size": 0, 
    },
    pool_pre_ping=True,  
    pool_recycle=3600,   
    pool_size=10,        
    max_overflow=20      
)

AsyncSessionLocal = async_sessionmaker(bind=engine, class_=AsyncSession, expire_on_commit=False)
Base = declarative_base()

async def get_db():
    async with AsyncSessionLocal() as session:
        yield session