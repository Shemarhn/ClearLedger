import unittest

from services.receipt_text_parser import (
    extract_receipt_candidates,
    parse_receipt_text_basic,
    prepare_receipt_ocr_text,
    reconcile_receipt_result,
)


SAMPLE_RECEIPT = """
KFC HALF WAY TREE
15 Hope Road
DATE: 07/05/2026
Chicken Combo           1200.00
GCT                     180.00
SUBTOTAL                1200.00
TOTAL                   1380.00
CASH TENDERED           2000.00
CHANGE                  620.00
"""


class ReceiptTextParserTests(unittest.TestCase):
    def test_extracts_receipt_candidates_from_ocr_text(self):
        candidates = extract_receipt_candidates(SAMPLE_RECEIPT)

        self.assertEqual(candidates["best_guess"]["merchant"], "Kfc Half Way Tree")
        self.assertEqual(candidates["best_guess"]["amount"], 1380.0)
        self.assertEqual(candidates["best_guess"]["date"], "2026-05-07")
        self.assertEqual(candidates["best_guess"]["category"], "Food")
        self.assertEqual(candidates["best_guess"]["line_items"][0]["name"], "Chicken Combo")

    def test_basic_parser_returns_reviewable_transaction(self):
        parsed = parse_receipt_text_basic(SAMPLE_RECEIPT)

        self.assertEqual(parsed["merchant"], "Kfc Half Way Tree")
        self.assertEqual(parsed["amount"], 1380.0)
        self.assertEqual(parsed["currency"], "JMD")
        self.assertEqual(parsed["category"], "Food")
        self.assertGreater(parsed["confidence"], 0.5)

    def test_reconcile_anchors_llm_amount_to_candidate_total(self):
        candidates = extract_receipt_candidates(SAMPLE_RECEIPT)
        result = reconcile_receipt_result(
            {
                "merchant": "KFC",
                "amount": 9999.0,
                "currency": "JMD",
                "category": "Food",
                "confidence": 0.92,
            },
            candidates,
        )

        self.assertEqual(result["amount"], 1380.0)
        self.assertLessEqual(result["confidence"], 0.65)

    def test_prepare_receipt_ocr_text_preserves_lines(self):
        prepared = prepare_receipt_ocr_text("  A  \r\n\r\n  B   C  ")

        self.assertEqual(prepared, "A\nB C")


if __name__ == "__main__":
    unittest.main()
