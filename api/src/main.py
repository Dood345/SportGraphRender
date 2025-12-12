import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware


from .router import soccer_router


logging.basicConfig(
    level=logging.INFO,  # Enables INFO logs (fixes your issue)
    format="[%(levelname)s] %(message)s",
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """FastAPI lifespan context."""
    # Memory Graph loads lazily on first dependency call, 
    # or we could force load here, but simpler to do nothing.
    logger.info("Application Startup")
    yield
    logger.info("Application Shutdown")


app = FastAPI(lifespan=lifespan)

app.include_router(soccer_router.router)


# --- THIS MIDDLEWARE CONFIGURATION ---
# Define the origins allowed to make requests (frontend URL)
origins = [
    "http://localhost:5173",
    "http://127.0.0.1:5173",
]

# Add production frontend URL if set
import os
if os.getenv("FRONTEND_URL"):
    origins.append(os.getenv("FRONTEND_URL"))


app = CORSMiddleware(
    app=app,
    allow_origins=origins,  # List of allowed origins
    allow_credentials=True,  # Allow cookies if needed for auth later
    allow_methods=["*"],  # Allow all standard methods (GET, POST, PUT, DELETE, OPTIONS,etc.)
    allow_headers=["*"],  # Allow all headers
    expose_headers=["Content-Disposition"],
)
# --------------------------------------
