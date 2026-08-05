const { reconcile } = require("./reconcile");

console.log("transaction-reconciler starting...");

try {
  reconcile();
  console.log("Reconciliation complete. Log written to /app/output/reconcile.log");
} catch (err) {
  console.error("Reconciliation failed:", err.message);
  process.exit(1);
}
