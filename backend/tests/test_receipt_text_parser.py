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

MULTI_ITEM_RECEIPT_WITHOUT_TOTAL = """
DIGINET JAMAICA LIMITED
DATE: 28/04/2026
Dymo-Per Label maker       8650.00
Dymo Labelling Tape        2500.00
CARD ****1234
"""

AMAZON_ORDER_RECEIPT = """
Search or ask a question
Hicarer 9 Pieces Spiked Studded Bracelet
Sold by: XunstoreYang
Return or replace items: Eligible through June 5, 2026
$15.99
View your item
Get product support
Buy it again
Track package
Order summary
Order placed May 4, 2026
Order # 113-4410901-3057839
Item(s) Subtotal: JMD 2,504.19
Shipping & Handling: JMD 0.00
Total before tax: JMD 2,504.19
Estimated tax to be collected: JMD 0.00
Exchange rate guarantee fee: JMD 50.09
Grand Total: JMD 2,554.28
Exchange rate
1 USD = 156.6099669 JMD
View invoice
Payment method
Mastercard ending in 0304
Ship to
Shemar Marks
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

    def test_uses_line_item_sum_when_receipt_has_no_total_line(self):
        candidates = extract_receipt_candidates(MULTI_ITEM_RECEIPT_WITHOUT_TOTAL)

        self.assertEqual(candidates["best_guess"]["amount"], 11150.0)

        result = reconcile_receipt_result(
            {
                "merchant": "Diginet Jamaica Limited",
                "amount": 8650.0,
                "currency": "JMD",
                "line_items": candidates["best_guess"]["line_items"],
                "confidence": 0.9,
            },
            candidates,
        )

        self.assertEqual(result["amount"], 11150.0)

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

    def test_amazon_order_ignores_app_chrome_and_exchange_rate_metadata(self):
        candidates = extract_receipt_candidates(AMAZON_ORDER_RECEIPT)
        best_guess = candidates["best_guess"]

        self.assertEqual(best_guess["merchant"], "Amazon")
        self.assertEqual(best_guess["amount"], 2554.28)
        self.assertEqual(best_guess["currency"], "JMD")
        self.assertEqual(best_guess["date"], "2026-05-04")
        self.assertEqual(best_guess["transaction_type"], "expense")
        self.assertEqual(best_guess["category"], "Shopping")
        self.assertEqual(best_guess["card_last4"], "0304")

        item_names = [item["name"] for item in best_guess["line_items"]]
        self.assertNotIn("Return or replace items: Eligible through June", item_names)
        self.assertFalse(any("Order #" in item["line"] for item in best_guess["line_items"]))
        self.assertFalse(any("USD = 156" in item["line"] for item in best_guess["line_items"]))

    def test_prepare_receipt_ocr_text_preserves_lines(self):
        prepared = prepare_receipt_ocr_text("  A  \r\n\r\n  B   C  ")

        self.assertEqual(prepared, "A\nB C")


if __name__ == "__main__":
    unittest.main()
