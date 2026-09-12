"""Create AgentCore runtime via boto3 — fill placeholders, then run.

Does NOT run automatically. Official API:
  boto3.client('bedrock-agentcore-control').create_agent_runtime(...)
"""

from __future__ import annotations

import boto3

ACCOUNT_ID = "ACCOUNT_ID"
REGION = "us-east-1"
ROLE_ARN = f"arn:aws:iam::{ACCOUNT_ID}:role/AgentRuntimeRole"
ECR_URI = f"{ACCOUNT_ID}.dkr.ecr.{REGION}.amazonaws.com/studylife-strands-agent:latest"


def create_runtime() -> None:
    client = boto3.client("bedrock-agentcore-control", region_name=REGION)
    response = client.create_agent_runtime(
        agentRuntimeName="studylife-agent",
        agentRuntimeArtifact={
            "containerConfiguration": {
                "containerUri": ECR_URI,
            }
        },
        networkConfiguration={"networkMode": "PUBLIC"},
        roleArn=ROLE_ARN,
        environmentVariables={
            "BEDROCK_MODEL_ID": "global.anthropic.claude-sonnet-4-6",
            # Inject secrets via AgentCore / Secrets Manager in production —
            # do not commit real SUPABASE_* values here.
        },
    )
    print("Agent Runtime ARN:", response.get("agentRuntimeArn"))
    print("Status:", response.get("status"))


if __name__ == "__main__":
    create_runtime()
