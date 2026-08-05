from flask import Flask, jsonify

app = Flask(__name__)


@app.route("/health")
def health():
    return jsonify({"status": "ok"}), 200


@app.route("/notify/<merchant_id>")
def notify(merchant_id):
    return jsonify({"merchant_id": merchant_id, "notified": True}), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
