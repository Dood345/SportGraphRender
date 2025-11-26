import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from API.dependencies import get_connection_manager


logging.basicConfig(
    level=logging.INFO,     # Enables INFO logs (fixes your issue)
    format="[%(levelname)s] %(message)s",
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """FastAPI lifespan context: initialize and clean up shared resources."""
    # ---- STARTUP ----
    connection_manager = get_connection_manager()

    yield

    # ---- SHUTDOWN ----
    connection_manager.close_all()


app = FastAPI(lifespan=lifespan)


# --- THIS MIDDLEWARE CONFIGURATION ---
# Define the origins allowed to make requests (frontend URL)
origins = [
    "http://localhost:5173",
    "http://127.0.0.1:5173",
]

app = CORSMiddleware(
    app=app,
    allow_origins=origins, # List of allowed origins
    allow_credentials=True, # Allow cookies if needed for auth later
    allow_methods=["*"], # Allow all standard methods (GET, POST, PUT, DELETE, OPTIONS,etc.)
    allow_headers=["*"], # Allow all headers
    expose_headers=["Content-Disposition"]
)
# --------------------------------------

