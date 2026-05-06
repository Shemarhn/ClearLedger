"""Helpers for validating Supabase access tokens."""

import asyncio
import json
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from config import SUPABASE_PUBLISHABLE_KEY, SUPABASE_URL

security = HTTPBearer(auto_error=True)
AUTH_TIMEOUT_SECONDS = 10


def _fetch_supabase_user(token: str) -> dict:
    """Ask Supabase Auth to validate the user access token."""
    request = Request(
        f"{SUPABASE_URL.rstrip('/')}/auth/v1/user",
        headers={
            "apikey": SUPABASE_PUBLISHABLE_KEY,
            "Authorization": f"Bearer {token}",
        },
        method="GET",
    )

    with urlopen(request, timeout=AUTH_TIMEOUT_SECONDS) as response:
        body = response.read().decode("utf-8")
    user = json.loads(body)

    if not isinstance(user, dict) or not user.get("id"):
        raise ValueError("Supabase Auth returned an invalid user payload.")

    return user


async def verify_jwt(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> dict:
    """
    Validate a Supabase access token with Supabase Auth.
    Returns a payload-like dictionary containing sub (user_id), email, and user.
    """
    if not SUPABASE_URL or not SUPABASE_PUBLISHABLE_KEY:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Server is missing Supabase auth configuration.",
        )

    token = credentials.credentials
    try:
        user = await asyncio.to_thread(_fetch_supabase_user, token)
        return {
            "sub": user["id"],
            "email": user.get("email"),
            "user": user,
        }
    except HTTPError as e:
        if e.code in (status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or expired token. Please log in again.",
            )
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Could not validate token with Supabase Auth.",
        )
    except URLError:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Supabase Auth is unavailable. Please try again.",
        )
    except (json.JSONDecodeError, ValueError):
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Supabase Auth returned an invalid response.",
        )


def get_user_id(payload: dict = Depends(verify_jwt)) -> str:
    """Extract the user_id (sub) from the verified JWT payload."""
    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token does not contain a valid user ID.",
        )
    return user_id
