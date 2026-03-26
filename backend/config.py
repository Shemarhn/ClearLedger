"""Application configuration loaded from environment variables."""

import os
from dotenv import load_dotenv

load_dotenv()

# Supabase
SUPABASE_URL: str = os.getenv("SUPABASE_URL", "")
SUPABASE_SERVICE_ROLE_KEY: str = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
SUPABASE_JWT_SECRET: str = os.getenv("SUPABASE_JWT_SECRET", "")

# LLM APIs
GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY", "")
ANTHROPIC_API_KEY: str = os.getenv("ANTHROPIC_API_KEY", "")

# App
PORT: int = int(os.getenv("PORT", "8000"))
CORS_ORIGINS: str = os.getenv("CORS_ORIGINS", "*")


def get_cors_origins() -> list[str]:
	if CORS_ORIGINS.strip() == "*":
		return ["*"]
	return [origin.strip() for origin in CORS_ORIGINS.split(",") if origin.strip()]


def validate_required_config() -> None:
	missing = []
	if not SUPABASE_URL:
		missing.append("SUPABASE_URL")
	if not SUPABASE_SERVICE_ROLE_KEY:
		missing.append("SUPABASE_SERVICE_ROLE_KEY")
	if not SUPABASE_JWT_SECRET:
		missing.append("SUPABASE_JWT_SECRET")
	if missing:
		raise RuntimeError(f"Missing required environment variables: {', '.join(missing)}")
