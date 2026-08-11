# --- build stage ---
FROM python:3.12-slim AS build

WORKDIR /build
COPY app/requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# --- runtime stage ---
FROM python:3.12-slim

RUN groupadd -r appgroup && useradd -r -g appgroup appuser

COPY --from=build /install /usr/local
WORKDIR /app
COPY app/app.py .

RUN mkdir -p /data/invoices

USER appuser

EXPOSE 8080
ENV PORT=8080

CMD ["gunicorn", "--workers", "2", "--bind", "0.0.0.0:8080", "app:app"]
