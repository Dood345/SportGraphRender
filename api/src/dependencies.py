
import os
import logging
from functools import lru_cache

from src.repository.sql_repository import SQLRepository
from API.Repository.postgres_connection_manager import PostgresConnectionManager


load_dotenv()


logger = logging.getLogger(__name__)


# ============================================================
# 🔌 DATABASE CLIENT SETUP
# ============================================================


@lru_cache()
def get_postgres_connection_manager() -> PostgresConnectionManager:
    """Create and return a PostgreSQL connection manager."""
    db_host = os.environ["DB_HOST"]
    db_port = os.environ["DB_PORT"]
    db_name = os.environ["DB_NAME"]
    db_user = os.environ["DB_USER"]
    db_password = os.environ["DB_PASSWORD"]

    db_url = f"postgresql://{db_user}:{db_password}@{db_host}:{db_port}/{db_name}"

    return PostgresConnectionManager(db_url=db_url)


# ============================================================
# 🏗️ REPOSITORY SETUP
# ============================================================


def get_postgres_sql_repository(
    pcm: PostgresConnectionManager = Depends(get_postgres_connection_manager),
) -> PostgresSqlRepository:
    """Provide an SQL repository using the connection manager."""
    return PostgresSqlRepository(pcm)


# ============================================================
# 🧩 SERVICE SETUP
# ============================================================


def get_soccer_service(
    psr: SQLRepository = Depends(get_postgres_sql_repository),
) -> SoccerService:
    """Provide an AuthService using the SQL repository."""
    return SoccerService(psr)

