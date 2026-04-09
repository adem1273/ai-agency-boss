import os
from typing import List

from fastapi import FastAPI, Depends, APIRouter
from fastapi.middleware.cors import CORSMiddleware

from backend.core.auth import get_current_user_id, create_access_token


def parse_origins(value: str) -> List[str]:
    return [v.strip() for v in value.split(",") if v.strip()]


CORS_ORIGINS = parse_origins(os.getenv("CORS_ORIGINS", "http://localhost:3000"))

app = FastAPI(title="ai-agency-boss")

app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

public = APIRouter()
protected = APIRouter(dependencies=[Depends(get_current_user_id)])


@public.get("/health")
def health():
    return {"ok": True}


# Demo amaçlı: gerçek projede register/login endpointleri ayrıca yazılacak.
# Shared server güvenliği için prod ortamında kapatın.
@public.post("/dev/token")
def dev_token(user_id: str):
    return {"access_token": create_access_token(user_id=user_id), "token_type": "bearer"}


@protected.get("/me")
def me(current_user_id: str = Depends(get_current_user_id)):
    return {"user_id": current_user_id}


app.include_router(public)
app.include_router(protected)
