import os
import json
import time
import uuid

import boto3
from botocore.exceptions import ClientError
from flask import Flask, jsonify

app = Flask(__name__)

BUCKET = os.environ.get("AUDIT_BUCKET", "")
REGION = os.environ.get("AWS_REGION", "ap-south-1")

s3 = boto3.client("s3", region_name=REGION)


@app.route("/healthz")
def healthz():
    return jsonify({"status": "ok"}), 200


@app.route("/audit/write")
def write_audit_record():
    record_id = str(uuid.uuid4())
    key = f"audit-records/{record_id}.json"
    body = json.dumps({
        "record_id": record_id,
        "event": "transaction.processed",
        "timestamp": time.time(),
    })

    try:
        s3.put_object(Bucket=BUCKET, Key=key, Body=body)
        return jsonify({"written": key, "bucket": BUCKET}), 200
    except ClientError as e:
        return jsonify({"error": str(e), "bucket": BUCKET}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5000)))
