import os
import logging
from datetime import datetime, timezone
from pathlib import Path

from flask import Flask, request, jsonify, send_file
from fpdf import FPDF

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
log = logging.getLogger("billing-invoice-service")

INVOICE_DIR = Path("/data/invoices")


@app.route("/healthz", methods=["GET"])
def healthz():
    return jsonify({"status": "ok", "service": "billing-invoice-service"}), 200


@app.route("/api/v1/invoices", methods=["POST"])
def generate_invoice():
    payload = request.get_json(silent=True)
    if not payload or "customer_id" not in payload or "amount_due" not in payload:
        return jsonify({"error": "customer_id and amount_due are required"}), 400

    invoice_id = f"{payload['customer_id']}-{int(datetime.now(timezone.utc).timestamp())}"
    invoice_path = INVOICE_DIR / f"{invoice_id}.pdf"

    pdf = FPDF()
    pdf.add_page()
    pdf.set_font("Helvetica", size=14)
    pdf.cell(0, 10, "Vantra Utility Billing - Invoice", ln=True)
    pdf.set_font("Helvetica", size=11)
    pdf.cell(0, 10, f"Customer: {payload['customer_id']}", ln=True)
    pdf.cell(0, 10, f"Amount due: {payload['amount_due']}", ln=True)
    pdf.output(str(invoice_path))

    log.info("Generated invoice %s", invoice_id)
    return jsonify({"invoice_id": invoice_id}), 201


@app.route("/api/v1/invoices/<invoice_id>", methods=["GET"])
def fetch_invoice(invoice_id):
    invoice_path = INVOICE_DIR / f"{invoice_id}.pdf"
    if not invoice_path.exists():
        return jsonify({"error": "not found"}), 404
    return send_file(invoice_path, mimetype="application/pdf")


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8080"))
    app.run(host="0.0.0.0", port=port)
