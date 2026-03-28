"""Endpoints for generating PDF and CSV exports."""

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import Response
from supabase import create_client

from auth import get_user_id
from config import SUPABASE_SERVICE_ROLE_KEY, SUPABASE_URL
from models import ExportRequest
from services.export_service import generate_csv, generate_pdf

router = APIRouter(prefix="/export", tags=["Export"])


def _get_supabase():
    return create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)


async def _get_transactions_for_period(user_id: str, start_date, end_date):
    supabase = _get_supabase()
    result = (
        supabase.table("transactions")
        .select("*")
        .eq("user_id", user_id)
        .gte("transaction_date", start_date.isoformat())
        .lte("transaction_date", end_date.isoformat())
        .order("transaction_date", desc=True)
        .execute()
    )
    return result.data or []


def _get_user_name(user_id: str) -> str:
    supabase = _get_supabase()
    profile = (
        supabase.table("profiles")
        .select("full_name")
        .eq("id", user_id)
        .single()
        .execute()
    )
    return profile.data.get("full_name", "User") if profile.data else "User"


@router.post("/pdf")
async def export_pdf(body: ExportRequest, user_id: str = Depends(get_user_id)):
    """
    Generate a PDF report of transactions for the given date range.
    Returns the PDF as a downloadable file.
    """
    if body.start_date > body.end_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="start_date must be before or equal to end_date.",
        )

    transactions = await _get_transactions_for_period(user_id, body.start_date, body.end_date)
    user_name = _get_user_name(user_id)
    pdf_bytes = generate_pdf(transactions, body.start_date, body.end_date, user_name)

    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={
            "Content-Disposition": (
                f'attachment; filename="clearledger_report_{body.start_date}_{body.end_date}.pdf"'
            )
        },
    )


@router.post("/csv")
async def export_csv(body: ExportRequest, user_id: str = Depends(get_user_id)):
    """
    Generate a CSV report of transactions for the given date range.
    Returns the CSV as a downloadable file.
    """
    if body.start_date > body.end_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="start_date must be before or equal to end_date.",
        )

    transactions = await _get_transactions_for_period(user_id, body.start_date, body.end_date)

    csv_content = generate_csv(transactions)

    return Response(
        content=csv_content,
        media_type="text/csv",
        headers={
            "Content-Disposition": (
                f'attachment; filename="clearledger_export_{body.start_date}_{body.end_date}.csv"'
            )
        },
    )


@router.post("/export/pdf")
async def export_pdf_alias(body: ExportRequest, user_id: str = Depends(get_user_id)):
    return await export_pdf(body=body, user_id=user_id)


@router.post("/export/csv")
async def export_csv_alias(body: ExportRequest, user_id: str = Depends(get_user_id)):
    return await export_csv(body=body, user_id=user_id)
