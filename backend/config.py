"""Application configuration loaded from environment variables."""

import os
from dotenv import load_dotenv

load_dotenv()

# Supabase
SUPABASE_URL: str = os.getenv("SUPABASE_URL", "")
SUPABASE_PUBLISHABLE_KEY: str = os.getenv("SUPABASE_PUBLISHABLE_KEY", "")
SUPABASE_SECRET_KEY: str = os.getenv("SUPABASE_SECRET_KEY", "")

# LLM APIs
GOOGLE_AI_API_KEY: str = (
    os.getenv("GEMINI_API_KEY")
    or os.getenv("GOOGLE_AI_API_KEY")
    or os.getenv("GEMMA_API_KEY")
    or ""
)
GEMINI_API_KEY: str = GOOGLE_AI_API_KEY
GEMINI_MODEL: str = os.getenv("GEMINI_MODEL", "gemini-2.5-flash-lite")
GEMMA_API_KEY: str = os.getenv("GEMMA_API_KEY") or GOOGLE_AI_API_KEY
GEMMA_MODEL: str = os.getenv("GEMMA_MODEL", "gemma-4-31b-it")
ANTHROPIC_API_KEY: str = os.getenv("ANTHROPIC_API_KEY", "")

# App
PORT: int = int(os.getenv("PORT", "8000"))
CORS_ORIGINS: str = os.getenv("CORS_ORIGINS", "*")


def get_cors_origins() -> list[str]:
    if CORS_ORIGINS.strip() == "*":
        return ["*"]
    return [origin.strip() for origin in CORS_ORIGINS.split(",") if origin.strip()]


def allow_cors_credentials() -> bool:
    return "*" not in get_cors_origins()


def validate_required_config() -> None:
    missing = []
    if not SUPABASE_URL:
        missing.append("SUPABASE_URL")
    if not SUPABASE_PUBLISHABLE_KEY:
        missing.append("SUPABASE_PUBLISHABLE_KEY")
    if not SUPABASE_SECRET_KEY:
        missing.append("SUPABASE_SECRET_KEY")
    if not GOOGLE_AI_API_KEY:
        missing.append("GEMINI_API_KEY or GOOGLE_AI_API_KEY")
    if missing:
        raise RuntimeError(f"Missing required environment variables: {', '.join(missing)}")
