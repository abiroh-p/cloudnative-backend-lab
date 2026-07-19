# WHY this file exists:
# Industry-standard practice ("12-factor app" principle) is: config comes
# from environment variables, never hardcoded into source. This makes the
# exact same code work in local dev, CI, and production just by changing
# env vars — no code edits, no redeploys for a config change.
#
# pydantic-settings gives us env-var loading WITH validation: if a required
# var is missing or the wrong type, the app fails fast at startup with a
# clear error, instead of failing confusingly later at first DB query.

import logging

from pydantic_settings import BaseSettings, SettingsConfigDict

logger = logging.getLogger(__name__)


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    # Database
    postgres_user: str = "appuser"
    postgres_password: str = "changeme"
    postgres_db: str = "appdb"
    postgres_host: str = "db"          # "db" matches the docker-compose service name
    postgres_port: int = 5432
    postgres_sslmode: str = "prefer"   # WHY "prefer": tries SSL first, falls back to plain if
                                        # unavailable. Local docker Postgres has no SSL configured,
                                        # Azure Postgres REQUIRES it — "prefer" works correctly
                                        # against both without needing a per-environment switch.

    # Key Vault — when set, postgres_password above gets OVERWRITTEN by the
    # real secret fetched from the vault (see below). Leave unset to keep
    # using postgres_password as-is (e.g. against local docker Postgres).
    key_vault_uri: str | None = None

    # App
    environment: str = "local"
    log_level: str = "INFO"

    @property
    def database_url(self) -> str:
        return (
            f"postgresql+psycopg2://{self.postgres_user}:{self.postgres_password}"
            f"@{self.postgres_host}:{self.postgres_port}/{self.postgres_db}"
            f"?sslmode={self.postgres_sslmode}"
        )


settings = Settings()


def resolve_secrets() -> None:
    """
    Fetches real secret values from Key Vault, overwriting the placeholder
    settings loaded above. Deliberately NOT run automatically at import
    time (unlike the previous version of this file) — logging isn't
    configured yet when this module is first imported, so any logging
    from here would be silently dropped. main.py calls this explicitly,
    AFTER configure_logging() has run, so this function's log lines
    actually appear.
    """
    if not settings.key_vault_uri:
        return

    from azure.identity import DefaultAzureCredential
    from azure.keyvault.secrets import SecretClient

    # WHY DefaultAzureCredential specifically:
    # This is the one piece of code that works UNCHANGED in every
    # environment this app will ever run in:
    #   - locally in this devcontainer: falls back to your own `az login`
    #     session (AzureCliCredential, tried automatically)
    #   - later, running as a pod in AKS: automatically uses Workload
    #     Identity instead (WorkloadIdentityCredential, tried first)
    # DefaultAzureCredential tries several credential sources in order and
    # uses whichever one actually works — no branching logic needed here
    # for "am I local or in the cluster."
    logger.info("fetching_secret_from_key_vault", extra={"vault_uri": settings.key_vault_uri})
    credential = DefaultAzureCredential()
    client = SecretClient(vault_url=settings.key_vault_uri, credential=credential)
    settings.postgres_password = client.get_secret("postgres-admin-password").value
    logger.info("secret_fetch_succeeded")

