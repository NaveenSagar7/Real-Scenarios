const express = require('express');
const app = express();

const PORT = process.env.PORT || 3000;
const DB_HOST = process.env.DB_HOST;
const API_TIMEOUT_MS = process.env.API_TIMEOUT_MS || 5000;

if (!DB_HOST) {
  console.error('FATAL: DB_HOST environment variable is required to start cart-service');
  process.exit(1);
}

app.get('/healthz', (req, res) => res.status(200).json({ status: 'ok' }));

app.get('/cart/:userId', (req, res) => {
  res.json({ userId: req.params.userId, items: [], timeout: API_TIMEOUT_MS });
});

app.listen(PORT, () => {
  console.log(`cart-service listening on port ${PORT}, DB_HOST=${DB_HOST}`);
});