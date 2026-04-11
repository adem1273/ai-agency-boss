from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from pathlib import Path

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
from services.image_engine import ImageManager
from services.video_engine import VideoConcatenator

_image_manager = ImageManager()
_video_concatenator = VideoConcatenator()


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
    output_path = Path(path)
    output_posix = output_path.as_posix()
    if "/storage/" in output_posix:
        relative_path = output_posix.split("/storage/", 1)[1]
    elif output_posix.startswith("storage/"):
        relative_path = output_posix[len("storage/") :]
    else:
        relative_path = output_path.name

    output_url = f"/files/{relative_path.lstrip('/')}"
    return {"user_id": current_user_id, "output_path": path, "output_url": output_url}


class ConcatVideoRequest(BaseModel):
    input_paths: list[str] = Field(..., min_length=2)
    output_name: str = Field("merged.mp4", min_length=1, max_length=255)
    reencode: bool = True


@router.post("/concat-video")
def concat_video(
    body: ConcatVideoRequest,
    current_user_id: str = Depends(get_current_user_id),
):
    output_dir = Path("storage/outputs") / current_user_id
    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / body.output_name

    input_videos = [Path(p) for p in body.input_paths]
    _video_concatenator.render(input_videos=input_videos, output_path=output_path, reencode=body.reencode)

    output_url = f"/files/outputs/{current_user_id}/{output_path.name}"
    return {
        "user_id": current_user_id,
        "output_path": str(output_path),
        "output_url": output_url,
        "input_count": len(input_videos),
    }
