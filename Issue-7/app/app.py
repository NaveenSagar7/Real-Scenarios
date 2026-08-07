import os
import time
from flask import Flask, jsonify

app = Flask(__name__)

START_TIME = time.time()
SERVICE_NAME = os.environ.get("SERVICE_NAME", "streamly-api")
VERSION = os.environ.get("APP_VERSION", "1.0.0")


@app.route("/")
def root():
    return jsonify({
        "service": SERVICE_NAME,
        "version": VERSION,
        "message": "PulseStream catalog API"
    })


@app.route("/healthz")
def healthz():
    return jsonify({"status": "ok", "uptime_seconds": round(time.time() - START_TIME, 2)}), 200


@app.route("/catalog")
def catalog():
    titles = [
        {"id": 1, "title": "Midnight Signal", "genre": "Thriller"},
        {"id": 2, "title": "Reef Runners", "genre": "Documentary"},
        {"id": 3, "title": "Circuit City", "genre": "Sci-Fi"},
    ]
    return jsonify(titles)


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 3000))
    app.run(host="0.0.0.0", port=port)
