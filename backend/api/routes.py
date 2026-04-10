from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from core.auth import get_current_user_id
from services.ai_engine import AIManager

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
