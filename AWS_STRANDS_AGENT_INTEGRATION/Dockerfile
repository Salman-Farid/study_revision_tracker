# Amazon Bedrock AgentCore Runtime
# Requirements: linux/arm64 · port 8080 · GET /ping · POST /invocations
FROM --platform=linux/arm64 python:3.11-slim

WORKDIR /srv

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app
COPY agentcore_entry.py ./agentcore_entry.py
COPY bedrock_agentcore_config.json ./bedrock_agentcore_config.json

ENV PORT=8080
EXPOSE 8080

# Default: custom FastAPI (Option B) — already exposes /ping + /invocations + CORS.
# Alternative SDK entry (Option A): python agentcore_entry.py
# With CloudWatch OTel: ["opentelemetry-instrument", "uvicorn", "app.main:app", ...]
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
