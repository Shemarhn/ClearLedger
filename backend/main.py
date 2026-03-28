"""FastAPI entrypoint for the ClearLedger backend."""
import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from config import get_cors_origins, validate_required_config
from routes.parse import router as parse_router
from routes.export import router as export_router

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="ClearLedger API",
    description="Backend API for ClearLedger personal finance tracking app",
    version="1.0.0",
)

validate_required_config()

# CORS - allow Flutter app requests
app.add_middleware(
    CORSMiddleware,
    allow_origins=get_cors_origins(),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register routers
app.include_router(parse_router)
app.include_router(export_router)


@app.get("/health")
async def health_check():
    """Health check endpoint for Railway and monitoring."""
    return {"status": "ok", "service": "ClearLedger API"}
