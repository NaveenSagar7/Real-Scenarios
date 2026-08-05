# ---- Build stage ----
FROM node:20-alpine AS builder
WORKDIR /build
COPY app/package.json ./
RUN npm install --production
COPY app/ .

# ---- Final stage ----
FROM node:20-alpine AS final

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app
RUN mkdir -p /app/output

COPY --from=builder /build/package.json ./
COPY --from=builder /build/index.js ./
COPY --from=builder /build/reconcile.js ./

USER appuser

CMD ["node", "index.js"]
