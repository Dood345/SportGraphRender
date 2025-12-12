import os
import logging
from functools import lru_cache

from dotenv import load_dotenv
from fastapi import Depends

# New Memory Repository
from api.src.repository.memory_graph_repository import MemoryGraphRepository
from api.src.service.soccer_service import SoccerService


logger = logging.getLogger(__name__)

# Load env if exists
env_path = ".env"
if os.path.exists(env_path):
    load_dotenv(env_path)
    logger.info("Loaded environment variables from .env")
else:
    logger.info(".env file not found, assuming variables are set in environment")


# ============================================================
# 💾 REPOSITORY SETUP (In-Memory)
# ============================================================

@lru_cache(maxsize=1)
def get_memory_repository() -> MemoryGraphRepository:
    """Create and load the in-memory graph repository."""
    repo = MemoryGraphRepository()
    return repo


# ============================================================
# 🧩 SERVICE SETUP
# ============================================================

def get_soccer_service(repo: MemoryGraphRepository = Depends(get_memory_repository)) -> SoccerService:
    """Provide an SoccerService using the Memory Repository."""
    return SoccerService(repo)
