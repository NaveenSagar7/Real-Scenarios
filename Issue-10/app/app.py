import os
import json
import uuid
import logging
from datetime import datetime, timezone

import boto3
from flask import Flask, request, jsonify

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("meter-reading-ingest")

app = Flask(__name__)

REGION = os.environ.get("AWS_REGION", "ap-south-1")
BUCKET = os.environ.get("METER_BUCKET")
TABLE = os.environ.get("METER_TABLE")

s3 = boto3.client("s3", region_name=REGION)
dynamodb = boto3.resource("dynamodb", region_name=REGION)


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok"}), 200


@app.route("/ingest", methods=["POST"])
def ingest():
    payload = request.get_json(force=True, silent=True)
    if not payload or "meter_id" not in payload or "reading_kwh" not in payload:
        return jsonify({"error": "meter_id and reading_kwh are required"}), 400

    reading_id = str(uuid.uuid4())
    ts = datetime.now(timezone.utc).isoformat()

    try:
        s3.put_object(
            Bucket=BUCKET,
            Key=f"raw/{payload['meter_id']}/{reading_id}.json",
            Body=json.dumps(payload).encode("utf-8"),
        )
    except Exception as exc:
        logger.exception("Failed to write raw payload to S3")
        return jsonify({"error": "s3_write_failed", "detail": str(exc)}), 500

    try:
        table = dynamodb.Table(TABLE)
        table.put_item(
            Item={
                "meter_id": payload["meter_id"],
                "reading_id": reading_id,
                "reading_kwh": str(payload["reading_kwh"]),
                "ingested_at": ts,
            }
        )
    except Exception as exc:
        logger.exception("Failed to write normalized record to DynamoDB")
        return jsonify({"error": "dynamodb_write_failed", "detail": str(exc)}), 500

    return jsonify({"reading_id": reading_id, "ingested_at": ts}), 201


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
