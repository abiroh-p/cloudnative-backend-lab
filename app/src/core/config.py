# WHY this file exists:
# Industry-standard practice ("12-factor app" principle) is: config comes
# from environment variables, never hardcoded into source. This makes the
# exact same code work in local dev, CI, and production just by changing
# env vars — no code edits, no redeploys for a config change.
#
# pydantic-settings gives us env-var loading WITH validation: if a required
# var is missing or the wrong type, the app fails fast at startup with a
# clear error, instead of failing confusingly later at first DB query.

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    # Database
    postgres_user: str = "appuser"
    postgres_password: str = "changeme"
    postgres_db: str = "appdb"
    postgres_host: str = "db"          # "db" matches the docker-compose service name
    postgres_port: int = 5432

    # App
    environment: str = "local"
    log_level: str = "INFO"

    @property
    def database_url(self) -> str:
        return (
            f"postgresql+psycopg2://{self.postgres_user}:{self.postgres_password}"
            f"@{self.postgres_host}:{self.postgres_port}/{self.postgres_db}"
        )


settings = Settings()
