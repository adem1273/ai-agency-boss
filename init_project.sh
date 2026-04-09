#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="ai-agency-boss"

echo "[1/8] Creating folders..."
mkdir -p backend/core backend/services backend/api
mkdir -p frontend/src/app
mkdir -p storage/models storage/outputs

echo "[2/8] Writing backend security layer (backend/core/auth.py)..."
cat > backend/core/auth.py <<'PY'
import os
from datetime import datetime, timedelta, timezone
from typing import Optional, Dict, Any

import bcrypt
from jose import jwt, JWTError
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer


JWT_ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")
JWT_SECRET = os.getenv("JWT_SECRET", "CHANGE_ME_IN_ENV")  # 반드시 prod'da env ile değiştirin
JWT_EXPIRES_MINUTES = int(os.getenv("JWT_EXPIRES_MINUTES", "60"))

security = HTTPBearer(auto_error=False)


def hash_password(plain_password: str) -> str:
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(plain_password.encode("utf-8"), salt)
    return hashed.decode("utf-8")


def verify_password(plain_password: str, password_hash: str) -> bool:
    try:
        return bcrypt.checkpw(
            plain_password.encode("utf-8"),
            password_hash.encode("utf-8"),
        )
    except Exception:
        return False


def create_access_token(*, user_id: str, extra_claims: Optional[Dict[str, Any]] = None) -> str:
    now = datetime.now(timezone.utc)
    exp = now + timedelta(minutes=JWT_EXPIRES_MINUTES)

    payload: Dict[str, Any] = {
        "sub": user_id,         # subject = user_id
        "iat": int(now.timestamp()),
        "exp": int(exp.timestamp()),
    }
    if extra_claims:
        payload.update(extra_claims)

    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def decode_token(token: str) -> Dict[str, Any]:
    return jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])


def get_current_user_id(
    creds: Optional[HTTPAuthorizationCredentials] = Depends(security),
) -> str:
    if creds is None or not creds.credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Authorization: Bearer <token>",
        )

    token = creds.credentials
    try:
        payload = decode_token(token)
        user_id = payload.get("sub")
        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token: missing subject",
            )
        return str(user_id)
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        )


# Not: Bu projede tüm DB sorguları ve dosya erişimleri user_id ile scope edilmelidir.
# Örn: SELECT ... WHERE owner_user_id = current_user_id
PY

echo "[3/8] Writing FastAPI entrypoint (backend/main.py)..."
cat > backend/main.py <<'PY'
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
PY

echo "[4/8] Writing video infrastructure placeholder (backend/services/video_engine.py)..."
cat > backend/services/video_engine.py <<'PY'
import subprocess
from pathlib import Path
from typing import List, Optional


class VideoConcatenator:
    """
    FFmpeg tabanlı video birleştirme iskeleti.

    Not (GPU): Şimdilik CPU/FFmpeg komutlarıyla tasarlanmıştır.
    İleride NVENC / CUDA hızlandırma veya Stable Diffusion video pipeline'ları eklenecekse
    container'a GPU runtime ve uygun ffmpeg build gerekebilir.
    """

    def __init__(self, ffmpeg_bin: str = "ffmpeg"):
        self.ffmpeg_bin = ffmpeg_bin

    def render(self, input_videos: List[Path], output_path: Path, *, reencode: bool = True) -> None:
        """
        Placeholder: input_videos listesini birleştirip output_path'e yazar.

        TODO:
        - concat demuxer için liste dosyası üret
        - reencode=False ise stream copy (-c copy)
        - hata yönetimi ve loglama
        """
        raise NotImplementedError("VideoConcatenator.render is not implemented yet")

    def _run(self, args: List[str], *, cwd: Optional[Path] = None) -> None:
        proc = subprocess.run(
            args,
            cwd=str(cwd) if cwd else None,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        if proc.returncode != 0:
            raise RuntimeError(f"ffmpeg failed: {proc.stderr}")
PY

echo "[5/8] Writing backend requirements + Dockerfile..."
cat > backend/requirements.txt <<'TXT'
fastapi==0.115.0
uvicorn[standard]==0.30.6
python-jose[cryptography]==3.3.0
bcrypt==4.2.0
TXT

cat > backend/Dockerfile <<'DOCKER'
FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY . /app

EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
DOCKER

echo "[6/8] Writing frontend minimal Next.js scaffold if missing..."
if [[ ! -f frontend/package.json ]]; then
  cat > frontend/package.json <<'JSON'
{
  "name": "ai-agency-boss-frontend",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start -p 3000"
  },
  "dependencies": {
    "next": "14.2.5",
    "react": "18.3.1",
    "react-dom": "18.3.1"
  }
}
JSON

  # Minimal Next App Router page
  cat > frontend/src/app/page.tsx <<'TSX'
export default function Page() {
  return (
    <main style={{ padding: 24, fontFamily: "system-ui" }}>
      <h1>ai-agency-boss</h1>
      <p>Frontend skeleton is ready.</p>
      <p>API base URL: {process.env.NEXT_PUBLIC_API_BASE_URL}</p>
    </main>
  );
}
TSX

  cat > frontend/next.config.js <<'JS'
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true
};
module.exports = nextConfig;
JS
fi

cat > frontend/Dockerfile <<'DOCKER'
FROM node:20-alpine

WORKDIR /app

COPY package*.json /app/
RUN if [ -f package-lock.json ]; then npm ci; else npm install; fi

COPY . /app

EXPOSE 3000
CMD ["npm", "run", "dev", "--", "--hostname", "0.0.0.0", "--port", "3000"]
DOCKER

echo "[7/8] Writing docker-compose.yml + env example..."
cat > docker-compose.yml <<'YAML'
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: ai_agency_boss
      POSTGRES_USER: ai_agency_boss
      POSTGRES_PASSWORD: ai_agency_boss_dev
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data

  backend:
    build:
      context: ./backend
    environment:
      DATABASE_URL: postgresql://ai_agency_boss:ai_agency_boss_dev@postgres:5432/ai_agency_boss
      JWT_SECRET: change-me
      JWT_ALGORITHM: HS256
      JWT_EXPIRES_MINUTES: "60"
      CORS_ORIGINS: http://localhost:3000
    ports:
      - "8000:8000"
    depends_on:
      - postgres
    volumes:
      - ./storage:/app/storage

  frontend:
    build:
      context: ./frontend
    environment:
      NEXT_PUBLIC_API_BASE_URL: http://localhost:8000
    ports:
      - "3000:3000"
    depends_on:
      - backend

volumes:
  pgdata:
YAML

cat > .env.example <<'ENV'
# Backend
JWT_SECRET=change-me
JWT_ALGORITHM=HS256
JWT_EXPIRES_MINUTES=60
CORS_ORIGINS=http://localhost:3000

# Database (docker-compose uses its own env, but keep this for future tooling)
DATABASE_URL=postgresql://ai_agency_boss:ai_agency_boss_dev@localhost:5432/ai_agency_boss
ENV

echo "[8/8] Done."
echo ""
echo "Next steps:"
echo "  1) docker compose up --build"
echo "  2) Backend health:  http://localhost:8000/health"
echo "  3) Get dev token:   POST http://localhost:8000/dev/token?user_id=demo"
echo "  4) Protected route: GET  http://localhost:8000/me  (Authorization: Bearer <token>)"