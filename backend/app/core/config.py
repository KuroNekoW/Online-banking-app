from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_url: str = "postgresql+psycopg://banking_app:change-me-in-local-env@localhost:5432/banking"
    app_name: str = "Mobile Banking API"
    jwt_secret_key: str = "development-only-change-this-secret-before-deployment"
    jwt_algorithm: str = "HS256"
    access_token_minutes: int = 15
    refresh_token_days: int = 7
    seed_admin_email: str = "admin@banking.local"
    seed_admin_password: str = "ChangeThisAdminPassword123!"

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


@lru_cache
def get_settings() -> Settings:
    return Settings()
