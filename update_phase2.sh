#!/usr/bin/env bash
set -euo pipefail

MODEL_PATH_DEFAULT="storage/models/llama3"

echo "[1/6] Ensuring folders..."
mkdir -p backend/services backend/api storage/models

echo "[2/6] Creating backend/services/ai_engine.py ..."
cat > backend/services/ai_engine.py <<'PY'
import json
import os
from typing import Any, Dict, Optional

# Local-only Llama-3 inference via Hugging Face Transformers
# NOTE: This loads models from local disk; no external API calls.
#
# Expected model directory:
#   storage/models/llama3
#
# You should place a compatible Llama-3 model there (weights + tokenizer files).
#
# Environment knobs:
#   AI_MODEL_PATH: override model path
#   AI_DEVICE: "cuda" or "cpu" (default: auto)
#   AI_DTYPE: "auto" | "float16" | "bfloat16" | "float32" (default: auto)

from transformers import AutoTokenizer, AutoModelForCausalLM
import torch


class AIManager:
    def __init__(self, model_path: Optional[str] = None):
        self.model_path = model_path or os.getenv("AI_MODEL_PATH", "storage/models/llama3")
        self.device_pref = os.getenv("AI_DEVICE", "auto")
        self.dtype_pref = os.getenv("AI_DTYPE", "auto")

        self._tokenizer = None
        self._model = None

    def _resolve_device(self) -> str:
        if self.device_pref in ("cpu", "cuda"):
            return self.device_pref
        return "cuda" if torch.cuda.is_available() else "cpu"

    def _resolve_dtype(self, device: str):
        if self.dtype_pref == "float16":
            return torch.float16
        if self.dtype_pref == "bfloat16":
            return torch.bfloat16
        if self.dtype_pref == "float32":
            return torch.float32
        # auto:
        if device == "cuda":
            return torch.float16
        return torch.float32

    def _load(self) -> None:
        if self._model is not None and self._tokenizer is not None:
            return

        device = self._resolve_device()
        dtype = self._resolve_dtype(device)

        self._tokenizer = AutoTokenizer.from_pretrained(self.model_path, local_files_only=True)

        self._model = AutoModelForCausalLM.from_pretrained(
            self.model_path,
            local_files_only=True,
            torch_dtype=dtype,
            device_map="auto" if device == "cuda" else None,
        )

        if device == "cpu":
            self._model.to("cpu")

        self._model.eval()

    def generate_strategy(self, business_description: str) -> Dict[str, Any]:
        """
        Given a business description, produce a JSON report including:
        - target_audience
        - slogan_suggestions
        - campaign_strategy

        Returns a Python dict (already parsed JSON).
        """
        self._load()

        prompt = f"""
You are an AI advertising strategist. You must output ONLY valid JSON.

Business description:
{business_description}

Return a JSON object with exactly these keys:
- "target_audience": an array of audience segments with brief reasoning
- "slogan_suggestions": an array of 5 short slogan ideas
- "campaign_strategy": an object with channels, creative angles, and a 7-day action plan

Rules:
- Output must be valid JSON.
- Do not include markdown.
"""

        inputs = self._tokenizer(prompt, return_tensors="pt")
        device = self._resolve_device()
        if device == "cuda":
            inputs = {k: v.to(self._model.device) for k, v in inputs.items()}

        with torch.no_grad():
            out = self._model.generate(
                **inputs,
                max_new_tokens=600,
                do_sample=True,
                temperature=0.7,
                top_p=0.9,
                eos_token_id=self._tokenizer.eos_token_id,
            )

        text = self._tokenizer.decode(out[0], skip_special_tokens=True)

        # Try to extract JSON (model might echo prompt). Take substring from first { to last }.
        start = text.find("{")
        end = text.rfind("}")
        if start == -1 or end == -1 or end <= start:
            raise ValueError("Model output did not contain a JSON object.")

        json_text = text[start : end + 1]

        try:
            return json.loads(json_text)
        except json.JSONDecodeError as e:
            raise ValueError(f"Invalid JSON produced by model: {e}") from e
PY

echo "[3/6] Creating backend/api/routes.py ..."
cat > backend/api/routes.py <<'PY'
from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from backend.core.auth import get_current_user_id
from backend.services.ai_engine import AIManager

router = APIRouter(prefix="", tags=["ai"])

ai_manager = AIManager()


class AnalyzeRequest(BaseModel):
    business_description: str = Field(..., min_length=10, max_length=10_000)


@router.post("/analyze")
def analyze(
    body: AnalyzeRequest,
    current_user_id: str = Depends(get_current_user_id),
):
    # Important: All future persistence must be scoped by current_user_id.
    report = ai_manager.generate_strategy(body.business_description)
    return {"user_id": current_user_id, "report": report}
PY

echo "[4/6] Updating backend/main.py to include routes (if not already)..."
if ! grep -q "backend.api.routes" backend/main.py; then
  # Insert import and include_router at end safely.
  # Append minimal include.
  cat >> backend/main.py <<'PY'

# Phase-2 routes
from backend.api.routes import router as ai_router

app.include_router(ai_router)
PY
fi

echo "[5/6] Updating backend/requirements.txt (add torch/transformers/accelerate if missing)..."
touch backend/requirements.txt

ensure_line () {
  local line="$1"
  if ! grep -qE "^${line//\[/\\[}$" backend/requirements.txt 2>/dev/null; then
    # fallback: simple contains check
    if ! grep -q "${line%%=*}" backend/requirements.txt; then
      echo "$line" >> backend/requirements.txt
    fi
  fi
}

# Versions left flexible-ish because torch version depends on CPU/CUDA environment.
# Pinning can be done later once your deployment target is fixed.
if ! grep -qi "^torch" backend/requirements.txt; then echo "torch" >> backend/requirements.txt; fi
if ! grep -qi "^transformers" backend/requirements.txt; then echo "transformers" >> backend/requirements.txt; fi
if ! grep -qi "^accelerate" backend/requirements.txt; then echo "accelerate" >> backend/requirements.txt; fi

echo "[6/6] Writing .env.example additions..."
if [[ -f .env.example ]]; then
  if ! grep -q "^AI_MODEL_PATH=" .env.example; then
    cat >> .env.example <<'ENV'

# AI (local)
AI_MODEL_PATH=storage/models/llama3
AI_DEVICE=auto
AI_DTYPE=auto
ENV
  fi
else
  cat > .env.example <<'ENV'
AI_MODEL_PATH=storage/models/llama3
AI_DEVICE=auto
AI_DTYPE=auto
ENV
fi

echo "Done."
echo ""
echo "Next steps:"
echo "  1) Put your Llama-3 model files under: ${MODEL_PATH_DEFAULT}"
echo "  2) docker compose up --build"
echo "  3) POST http://localhost:8000/analyze (Authorization: Bearer <token>)"
PY