from fastapi import FastAPI

from app.api.auth import router as auth_router
from app.api.admin import router as admin_router
from app.api.customer import router as customer_router
from app.api.transfers import router as transfers_router
from app.core.config import get_settings

settings = get_settings()
app = FastAPI(title=settings.app_name, version="0.1.0")
app.include_router(auth_router)
app.include_router(customer_router)
app.include_router(transfers_router)
app.include_router(admin_router)


@app.get("/health", tags=["system"])
def health_check() -> dict[str, str]:
    return {"status": "ok"}
