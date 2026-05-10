import unittest

from services.receipt_intelligence import normalize_merchant_key, summarize_corrections


class ReceiptIntelligenceTests(unittest.TestCase):
    def test_normalizes_merchant_key_for_learning(self):
        self.assertEqual(normalize_merchant_key("DIGINET JAMAICA LIMITED"), "diginet jamaica")
        self.assertEqual(normalize_merchant_key("Amazon.com, Inc."), "amazon com")

    def test_summarizes_user_corrections(self):
        corrections = summarize_corrections(
            {
                "merchant": "Search or ask a question",
                "amount": 47986.3,
                "currency": "USD",
                "category": "Other",
                "transaction_type": "refund",
            },
            {
                "merchant": "Amazon",
                "amount": 2554.28,
                "currency": "JMD",
                "category": "Shopping",
                "transaction_type": "expense",
            },
        )

        self.assertEqual(corrections["merchant"]["to"], "Amazon")
        self.assertEqual(corrections["amount"]["to"], 2554.28)
        self.assertEqual(corrections["currency"]["to"], "JMD")
        self.assertEqual(corrections["category"]["to"], "Shopping")
        self.assertEqual(corrections["transaction_type"]["to"], "expense")

    def test_equivalent_numbers_are_not_marked_as_corrections(self):
        corrections = summarize_corrections({"amount": "2,554.28"}, {"amount": 2554.28})

        self.assertEqual(corrections, {})


if __name__ == "__main__":
    unittest.main()
