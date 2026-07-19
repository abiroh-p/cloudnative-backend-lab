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

# WHY azure-cli is installed here, even though it's not a Python dependency:
# DefaultAzureCredential's AzureCliCredential works by SHELLING OUT to the
# `az` binary to get a token — it does NOT read the ~/.azure token cache
# files directly. Without `az` actually installed, that credential source
# fails even with the host's ~/.azure mounted in (see docker-compose.yml).
#
# THIS IS A LOCAL-DEV-ONLY CONVENIENCE. In AKS (Stage 4), Workload Identity
# authenticates via ManagedIdentityCredential instead — no CLI binary
# involved at all. This adds real size to the image for something
# production never uses; flagged for cleanup via a multi-stage build once
# Stage 4 revisits this Dockerfile for real (see the multi-stage note
# further up in this file).
RUN pip install --no-cache-dir azure-cli

COPY src/ ./src/
COPY migrations/ ./migrations/
COPY alembic.ini .
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

EXPOSE 8000

CMD ["./entrypoint.sh"]
