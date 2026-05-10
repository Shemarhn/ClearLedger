"""
ClearLedger FastAPI - Export Service
Generates PDF and CSV reports for transaction data.
"""
import csv
import io
from datetime import date
from typing import Any

from reportlab.lib import colors
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import (
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)


def generate_pdf(
    transactions: list[dict[str, Any]],
    start_date: date,
    end_date: date,
    user_name: str = "User",
) -> bytes:
    """
    Generate a PDF report of transactions for a date range.

    Returns:
        PDF file as bytes.
    """
    buffer = io.BytesIO()
    doc = SimpleDocTemplate(
        buffer,
        pagesize=letter,
        rightMargin=0.75 * inch,
        leftMargin=0.75 * inch,
        topMargin=0.75 * inch,
        bottomMargin=0.75 * inch,
    )

    styles = getSampleStyleSheet()
    elements = []

    # Title
    title_style = ParagraphStyle(
        "CustomTitle",
        parent=styles["Title"],
        fontSize=20,
        spaceAfter=6,
        textColor=colors.HexColor("#1a1a2e"),
    )
    elements.append(Paragraph("ClearLedger Transaction Report", title_style))

    # Subtitle with date range
    subtitle_style = ParagraphStyle(
        "Subtitle",
        parent=styles["Normal"],
        fontSize=11,
        textColor=colors.HexColor("#666666"),
        spaceAfter=20,
    )
    elements.append(
        Paragraph(
            f"Report for {user_name} | {start_date.strftime('%B %d, %Y')} to {end_date.strftime('%B %d, %Y')}",
            subtitle_style,
        )
    )

    # Summary section
    total_amount = sum(
        float(t.get("amount", 0))
        for t in transactions
        if (t.get("transaction_type") or "expense") == "expense"
    )
    category_totals: dict[str, float] = {}
    report_currency = _report_currency(transactions)
    for t in transactions:
        cat = t.get("category", "Other")
        if (t.get("transaction_type") or "expense") != "expense":
            continue
        category_totals[cat] = category_totals.get(cat, 0) + float(t.get("amount", 0))

    summary_style = ParagraphStyle(
        "Summary",
        parent=styles["Normal"],
        fontSize=11,
        spaceAfter=4,
    )
    elements.append(Paragraph(f"<b>Total Transactions:</b> {len(transactions)}", summary_style))
    elements.append(
        Paragraph(f"<b>Total Spent:</b> {report_currency} {total_amount:,.2f}", summary_style)
    )
    elements.append(Spacer(1, 12))

    # Category breakdown
    elements.append(Paragraph("<b>Spending by Category</b>", summary_style))
    elements.append(Spacer(1, 6))

    if category_totals:
        cat_data = [["Category", f"Amount ({report_currency})", "% of Total"]]
        sorted_cats = sorted(category_totals.items(), key=lambda x: x[1], reverse=True)
        for cat, amount in sorted_cats:
            pct = (amount / total_amount * 100) if total_amount > 0 else 0
            cat_data.append([cat, f"{amount:,.2f}", f"{pct:.1f}%"])

        cat_table = Table(cat_data, colWidths=[2.5 * inch, 2 * inch, 1.5 * inch])
        cat_table.setStyle(
            TableStyle(
                [
                    ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#1a1a2e")),
                    ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                    ("ALIGN", (1, 0), (-1, -1), "RIGHT"),
                    ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
                    ("FONTSIZE", (0, 0), (-1, -1), 9),
                    ("BOTTOMPADDING", (0, 0), (-1, 0), 8),
                    ("TOPPADDING", (0, 0), (-1, 0), 8),
                    ("BOTTOMPADDING", (0, 1), (-1, -1), 4),
                    ("TOPPADDING", (0, 1), (-1, -1), 4),
                    ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#dddddd")),
                    ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#f8f8f8")]),
                ]
            )
        )
        elements.append(cat_table)
        elements.append(Spacer(1, 20))

    # Transaction table
    elements.append(Paragraph("<b>All Transactions</b>", summary_style))
    elements.append(Spacer(1, 6))

    if transactions:
        table_data = [["Date", "Type", "Merchant", "Category", f"Amount ({report_currency})", "Source"]]
        for t in transactions:
            table_data.append(
                [
                    t.get("transaction_date", "N/A"),
                    t.get("transaction_type", "expense"),
                    t.get("merchant", "Unknown")[:30],
                    t.get("category", "Other"),
                    f"{float(t.get('amount', 0)):,.2f}",
                    t.get("input_method", "N/A"),
                ]
            )

        tx_table = Table(
            table_data,
            colWidths=[1.0 * inch, 0.9 * inch, 1.5 * inch, 1.1 * inch, 1.2 * inch, 0.8 * inch],
        )
        tx_table.setStyle(
            TableStyle(
                [
                    ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#1a1a2e")),
                    ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                    ("ALIGN", (3, 0), (3, -1), "RIGHT"),
                    ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
                    ("FONTSIZE", (0, 0), (-1, -1), 8),
                    ("BOTTOMPADDING", (0, 0), (-1, 0), 8),
                    ("TOPPADDING", (0, 0), (-1, 0), 8),
                    ("BOTTOMPADDING", (0, 1), (-1, -1), 3),
                    ("TOPPADDING", (0, 1), (-1, -1), 3),
                    ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#dddddd")),
                    ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#f8f8f8")]),
                ]
            )
        )
        elements.append(tx_table)
    else:
        elements.append(Paragraph("No transactions found for this period.", summary_style))

    doc.build(elements)
    return buffer.getvalue()


def generate_csv(transactions: list[dict[str, Any]]) -> str:
    """
    Generate a CSV string of transactions.

    Returns:
        CSV content as a string.
    """
    output = io.StringIO()
    writer = csv.writer(output)

    # Header row
    writer.writerow(
        [
            "Date",
            "Merchant",
            "Category",
            "Type",
            "Description",
            "Amount",
            "Currency",
            "Card Last 4",
            "Fee Amount",
            "Input Method",
        ]
    )

    for t in transactions:
        writer.writerow(
            [
                t.get("transaction_date", ""),
                t.get("merchant", ""),
                t.get("category", ""),
                t.get("transaction_type", "expense"),
                t.get("description", ""),
                t.get("amount", 0),
                t.get("currency", "JMD"),
                t.get("card_last4", ""),
                t.get("fee_amount", ""),
                t.get("input_method", ""),
            ]
        )

    return output.getvalue()


def _report_currency(transactions: list[dict[str, Any]]) -> str:
    for transaction in transactions:
        currency = str(transaction.get("currency") or "").strip().upper()
        if currency:
            return currency
    return "JMD"
