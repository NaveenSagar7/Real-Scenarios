const fs = require("fs");
const path = require("path");
const dayjs = require("dayjs");

function reconcile() {
  const outputDir = path.join(__dirname, "..", "output");
  const logPath = path.join(outputDir, "reconcile.log");

  const fakeTransactions = [
    { id: "txn_001", status: "matched" },
    { id: "txn_002", status: "matched" },
    { id: "txn_003", status: "unmatched" },
  ];

  const timestamp = dayjs().format("YYYY-MM-DD HH:mm:ss");
  const lines = [`Reconciliation run: ${timestamp}`, ...fakeTransactions.map(
    (t) => `${t.id}: ${t.status}`
  )];

  fs.writeFileSync(logPath, lines.join("\n") + "\n");
}

module.exports = { reconcile };
