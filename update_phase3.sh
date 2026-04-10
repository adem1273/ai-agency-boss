#!/usr/bin/env bash
set -euo pipefail

OUTPUT_FOLDER_DEFAULT="storage/outputs"
MODEL_PATH_DEFAULT="storage/models/stable-diffusion"

echo "[1/6] Ensuring folders..."
mkdir -p backend/services backend/api storage/models "${OUTPUT_FOLDER_DEFAULT}"

echo "[2/6] Creating backend/services/image_engine.py ..."
cat > backend/services/image_engine.py <<'PY'
import os
import time
from pathlib import Path
from typing import Optional

import torch
from diffusers import StableDiffusionPipeline, StableDiffusionXLPipeline


class ImageManager:
    """
    Local Stable Diffusion image generation via Diffusers.

    Model path expectation (local-only):
      - SD 1.5 style: a local folder with config + weights
      - SDXL style: a local folder for SDXL weights
    No external APIs are used.

    Env knobs:
      IMAGE_MODEL_PATH: local model directory
      IMAGE_MODEL_TYPE: "sd15" | "sdxl"  (default: sd15)
      IMAGE_DEVICE: "auto" | "cuda" | "cpu" (default: auto)
      IMAGE_DTYPE: "auto" | "float16" | "bfloat16" | "float32" (default: auto)
      IMAGE_OUTPUT_DIR: output directory (default: storage/outputs)
    """

    def __init__(self, model_path: Optional[str] = None):
        self.model_path = model_path or os.getenv("IMAGE_MODEL_PATH", "storage/models/stable-diffusion")
        self.model_type = os.getenv("IMAGE_MODEL_TYPE", "sd15").lower()
        self.device_pref = os.getenv("IMAGE_DEVICE", "auto").lower()
        self.dtype_pref = os.getenv("IMAGE_DTYPE", "auto").lower()
        self.output_dir = Path(os.getenv("IMAGE_OUTPUT_DIR", "storage/outputs"))

        self._pipe = None

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
        if self._pipe is not None:
            return

        device = self._resolve_device()
        dtype = self._resolve_dtype(device)

        # local_files_only=True ensures no downloads / external calls.
        if self.model_type == "sdxl":
            pipe = StableDiffusionXLPipeline.from_pretrained(
                self.model_path,
                local_files_only=True,
                torch_dtype=dtype,
            )
        else:
            pipe = StableDiffusionPipeline.from_pretrained(
                self.model_path,
                local_files_only=True,
                torch_dtype=dtype,
            )

        # Safety / memory tweaks
        if device == "cuda":
            pipe = pipe.to("cuda")
            try:
                pipe.enable_attention_slicing()
            except Exception:
                pass
        else:
            pipe = pipe.to("cpu")

        self._pipe = pipe

    def generate_image(
        self,
        prompt: str,
        *,
        width: int = 512,
        height: int = 512,
        steps: int = 30,
        guidance_scale: float = 7.0,
        seed: Optional[int] = None,
        negative_prompt: Optional[str] = None,
    ) -> str:
        """
        Generates an image for a prompt and saves it under storage/outputs.
        Returns the saved file path (string).
        """
        self._load()
        self.output_dir.mkdir(parents=True, exist_ok=True)

        generator = None
        if seed is not None:
            device = self._resolve_device()
            generator = torch.Generator(device=device).manual_seed(int(seed))

        # SDXL uses slightly different defaults; keep args compatible.
        common_kwargs = dict(
            prompt=prompt,
            num_inference_steps=int(steps),
            guidance_scale=float(guidance_scale),
            generator=generator,
        )
        if negative_prompt:
            common_kwargs["negative_prompt"] = negative_prompt

        if self.model_type == "sdxl":
            # SDXL typical sizes: 1024; allow user overrides
            common_kwargs["width"] = int(width)
            common_kwargs["height"] = int(height)
        else:
            common_kwargs["width"] = int(width)
            common_kwargs["height"] = int(height)

        result = self._pipe(**common_kwargs)
        image = result.images[0]

        ts = int(time.time())
        safe_ts = str(ts)
        fname = f"img_{safe_ts}.png"
        out_path = self.output_dir / fname
        image.save(out_path)

        return str(out_path)
PY

echo "[3/6] Updating backend/api/routes.py to add /generate-image endpoint..."
# Ensure file exists
touch backend/api/routes.py

# Add imports/manager only if endpoint not present
if ! grep -q "generate-image" backend/api/routes.py; then
  # Append endpoint at end to avoid complex AST edits
  cat >> backend/api/routes.py <<'PY'

# --- Phase-3: Stable Diffusion image generation ---
from pydantic import BaseModel, Field
from backend.services.image_engine import ImageManager

_image_manager = ImageManager()


class GenerateImageRequest(BaseModel):
    prompt: str = Field(..., min_length=3, max_length=4000)
    width: int = Field(512, ge=256, le=2048)
    height: int = Field(512, ge=256, le=2048)
    steps: int = Field(30, ge=1, le=100)
    guidance_scale: float = Field(7.0, ge=0.0, le=20.0)
    seed: int | None = Field(None, ge=0, le=2**31 - 1)
    negative_prompt: str | None = Field(None, max_length=4000)


@router.post("/generate-image")
def generate_image(
    body: GenerateImageRequest,
    current_user_id: str = Depends(get_current_user_id),
):
    # NOTE: If/when you store outputs per user, scope path by current_user_id:
    # e.g., storage/outputs/<user_id>/...
    path = _image_manager.generate_image(
        prompt=body.prompt,
        width=body.width,
        height=body.height,
        steps=body.steps,
        guidance_scale=body.guidance_scale,
        seed=body.seed,
        negative_prompt=body.negative_prompt,
    )
    return {"user_id": current_user_id, "output_path": path}
PY
  echo "  Added /generate-image endpoint."
else
  echo "  /generate-image endpoint already present; skipping."
fi

echo "[4/6] Updating backend/requirements.txt..."
touch backend/requirements.txt

append_if_missing () {
  local pkg="$1"
  if ! grep -qiE "^${pkg}([<=> ].*)?$" backend/requirements.txt; then
    echo "$pkg" >> backend/requirements.txt
  fi
}

append_if_missing "diffusers"
append_if_missing "invisible-watermark"
append_if_missing "safetensors"

# pillow is usually pulled in, but ensure it exists for image saving
append_if_missing "Pillow"

echo "[5/6] Updating .env.example with Image settings..."
if [[ -f .env.example ]]; then
  if ! grep -q "^IMAGE_MODEL_PATH=" .env.example; then
    cat >> .env.example <<'ENV'

# Image (local Stable Diffusion)
IMAGE_MODEL_PATH=storage/models/stable-diffusion
IMAGE_MODEL_TYPE=sd15
IMAGE_DEVICE=auto
IMAGE_DTYPE=auto
IMAGE_OUTPUT_DIR=storage/outputs
ENV
  fi
else
  cat > .env.example <<'ENV'
IMAGE_MODEL_PATH=storage/models/stable-diffusion
IMAGE_MODEL_TYPE=sd15
IMAGE_DEVICE=auto
IMAGE_DTYPE=auto
IMAGE_OUTPUT_DIR=storage/outputs
ENV
fi

echo "[6/6] Done."
echo ""
echo "Next steps:"
echo "  1) Put Stable Diffusion model files under: ${MODEL_PATH_DEFAULT}"
echo "  2) docker compose up --build"
echo "  3) POST http://localhost:8000/generate-image (Authorization: Bearer <token>)"
echo ""
echo "Example curl:"
echo "  curl -X POST http://localhost:8000/generate-image \\"
echo "    -H 'Authorization: Bearer <token>' -H 'Content-Type: application/json' \\"
echo "    -d '{\"prompt\":\"A cinematic product photo of a coffee mug on a wooden table\"}'"