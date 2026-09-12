# AWS Strands Agent — Study Revision Tracker

Isolated **Python** backend using the **official Strands Agents SDK** (`strands-agents`).

- Flutter / Gemini Live stay **voice-only** (STT + TTS).
- This service owns **all tool calls** (topics, revisions, routines, plans).
- **Does not modify** any Dart/Flutter app files.

## Flow

```
Gemini Live STT → Flutter → POST /v1/agent/invoke (or AgentCore /invocations)
  → StudyLifeAgent (Strands) → tools → Supabase
  → JSON reply → Flutter → Gemini Live TTS
```

## Quick start (local)

```bash
cd AWS_STRANDS_AGENT_INTEGRATION
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # fill SUPABASE_URL, keys, model credentials
uvicorn app.main:app --host 0.0.0.0 --port 8080
```

Or AgentCore SDK wrapper locally:

```bash
python agentcore_entry.py
# POST http://localhost:8080/invocations
```

## API

| Method | Path | Notes |
|--------|------|--------|
| GET | `/health` | App health |
| GET | `/ping` | **AgentCore required** |
| POST | `/invocations` | **AgentCore required** — same logic as invoke |
| POST | `/v1/agent/invoke` | Flutter-facing API |
| POST | `/v1/monitor/run` | Cron / WorkManager |

CORS: `allow_origins=["*"]` (Flutter / AgentCore routing).

Response (invoke): `{ "summary", "mode", "needsConfirmation", "tool_trace" }`  
Response (`/invocations`): `{ "output": { ...same fields } }`

## Models

Default Strands provider: **Amazon Bedrock** (`BEDROCK_MODEL_ID`). See [model providers](https://strandsagents.com/docs/user-guide/concepts/model-providers/).

## Layout

```
agentcore_entry.py           BedrockAgentCoreApp wrapper (SDK Integration)
bedrock_agentcore_config.json
scripts/deploy_agentcore.py  boto3 create_agent_runtime (fill placeholders)
Dockerfile                   linux/arm64 · :8080 · uvicorn app.main:app
app/main.py                  FastAPI (CORS, /ping, /invocations, /v1/agent/invoke)
app/core/agent.py            StudyLifeAgent (strands.Agent)
app/core/auth.py             Supabase JWT
app/core/supabase_client.py
app/core/monitor.py
app/tools/*.py               @tool → same Supabase tables as Flutter
```

---

## Deploy to Bedrock AgentCore

> **Do not run these until you are ready to create real AWS resources.**  
> Fill `ACCOUNT_ID`, `REGION`, and secrets first. Official guide: [Python AgentCore](https://strandsagents.com/docs/user-guide/deploy/deploy_to_bedrock_agentcore/python/).

### 0. Prerequisites

- AWS CLI configured (`aws sts get-caller-identity`)
- Docker (or Finch/Podman) with `buildx` for **linux/arm64**
- IAM role for AgentCore (e.g. `AgentRuntimeRole`) with at least:
  - `bedrock:InvokeModel` (and related model access)
  - Logs / ECR pull as needed

### 1. Create ECR repository

```bash
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export REGION=us-east-1
export ECR_REPO=studylife-strands-agent

aws ecr create-repository \
  --repository-name "$ECR_REPO" \
  --region "$REGION"
```

### 2. Login, build (arm64), push

```bash
aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

cd AWS_STRANDS_AGENT_INTEGRATION
docker buildx create --use 2>/dev/null || true

docker buildx build \
  --platform linux/arm64 \
  -t "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$ECR_REPO:latest" \
  --push \
  .
```

Verify:

```bash
aws ecr describe-images \
  --repository-name "$ECR_REPO" \
  --region "$REGION"
```

### 3. Create the AgentCore agent (runtime)

Update **placeholders** in `scripts/deploy_agentcore.py` (`ACCOUNT_ID`, `REGION`, `ROLE_ARN`, `ECR_URI`), then:

```bash
cd AWS_STRANDS_AGENT_INTEGRATION
python scripts/deploy_agentcore.py
```

Equivalent raw CLI/boto3 shape (matches official docs `create_agent_runtime`):

```python
import boto3
client = boto3.client("bedrock-agentcore-control", region_name="us-east-1")
resp = client.create_agent_runtime(
    agentRuntimeName="studylife-agent",
    agentRuntimeArtifact={
        "containerConfiguration": {
            "containerUri": f"{ACCOUNT_ID}.dkr.ecr.{REGION}.amazonaws.com/studylife-strands-agent:latest",
        }
    },
    networkConfiguration={"networkMode": "PUBLIC"},
    roleArn=f"arn:aws:iam::{ACCOUNT_ID}:role/AgentRuntimeRole",
)
print(resp["agentRuntimeArn"], resp["status"])
```

Environment mapping is documented in `bedrock_agentcore_config.json`  
(`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_JWT_SECRET`, `BEDROCK_MODEL_ID`).

### 4. Retrieve invoke ARN / invoke URL

```bash
# After create — use agentRuntimeArn from the response
aws bedrock-agentcore-control list-agent-runtimes \
  --region "$REGION" \
  --query "agentRuntimeSummaries[?agentRuntimeName=='studylife-agent']"

# Invoke (session id must be 33+ characters)
python - <<'PY'
import boto3, json, uuid
client = boto3.client("bedrock-agentcore", region_name="us-east-1")
arn = "arn:aws:bedrock-agentcore:us-east-1:ACCOUNT_ID:runtime/studylife-agent-XXXX"
payload = json.dumps({
    "prompt": "Get my study overview",
    "mode": "chat",
    # jwt: optional if you pass Authorization-style token in payload
}).encode()
sid = str(uuid.uuid4()) + "000000000000"  # ≥33 chars
r = client.invoke_agent_runtime(
    agentRuntimeArn=arn,
    runtimeSessionId=sid,
    payload=payload,
    qualifier="DEFAULT",
)
print(r["response"].read())
PY
```

### 5. Observability (optional)

```bash
pip install 'aws-opentelemetry-distro>=0.10.1'
# Dockerfile CMD alternative:
# CMD ["opentelemetry-instrument", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
```

Enable CloudWatch **Transaction Search** once in the console.

---

## Security

- **Service role only on this server.** Flutter uses anon + RLS.
- JWT required on `/v1/agent/invoke` and `/invocations` (header or payload `jwt`).
- Never commit real Supabase keys (use `.env` / AgentCore env / Secrets Manager).

## Docker / AgentCore checklist

| Requirement | Status |
|-------------|--------|
| linux/arm64 | Dockerfile `FROM --platform=linux/arm64` |
| Port 8080 | `EXPOSE 8080` |
| GET `/ping` | `app/main.py` |
| POST `/invocations` | `app/main.py` + `agentcore_entry.py` |
| CORS | `allow_origins=["*"]` |
| SDK entry | `agentcore_entry.py` (`BedrockAgentCoreApp`) |
