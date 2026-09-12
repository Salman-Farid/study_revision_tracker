from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    supabase_url: str = ""
    supabase_service_role_key: str = ""
    supabase_jwt_secret: str = ""

    bedrock_model_id: str = "global.anthropic.claude-sonnet-4-6"
    aws_region: str = "us-east-1"

    port: int = 8080
    app_env: str = "dev"

    # Spaced-revision days — must match Flutter AppConstants.revisionDays
    revision_days: tuple[int, ...] = (1, 3, 7, 14, 30, 90)


@lru_cache
def get_settings() -> Settings:
    return Settings()
