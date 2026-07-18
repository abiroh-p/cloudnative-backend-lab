# WHY multi-stage isn't used yet:
# Multi-stage builds matter most when you have a compile step (e.g. Go, or
# installing build tools that shouldn't ship in the final image). Pure
# Python with prebuilt wheels doesn't need that complexity yet — this gets
# revisited in Stage 4 when image size/scan results actually matter for ACR.

FROM python:3.12-slim

WORKDIR /app

# Install dependencies first, separately from app code — Docker caches this
# layer, so code changes don't force a full dependency reinstall on rebuild.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src/ ./src/
COPY migrations/ ./migrations/
COPY alembic.ini .
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

EXPOSE 8000

CMD ["./entrypoint.sh"]
