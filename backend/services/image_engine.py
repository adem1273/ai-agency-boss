import os
import time
from pathlib import Path
from typing import Optional

from PIL import Image, ImageDraw, ImageFont

try:
    import torch
    from diffusers import StableDiffusionPipeline, StableDiffusionXLPipeline
except Exception:
    torch = None
    StableDiffusionPipeline = None
    StableDiffusionXLPipeline = None


class ImageManager:
    """
    Local Stable Diffusion image generation via Diffusers.

    Model path expectation (local-only):
      - SD 1.5 style: a local folder with config + weights
      - SDXL style: a local folder for SDXL weights
    No external APIs are used.

        Env knobs:
            IMAGE_MODEL_PATH: local model directory (default: storage/models/sd-turbo)
            IMAGE_MODEL_ID: HF model id for first-time download (default: stabilityai/sd-turbo)
            IMAGE_MODEL_TYPE: "sdturbo" | "sd15" | "sdxl"  (default: sdturbo)
            IMAGE_LOCAL_ONLY: "true" | "false" (default: false)
            IMAGE_ENABLE_DIFFUSERS: "true" | "false" (default: true)
      IMAGE_DEVICE: "auto" | "cuda" | "cpu" (default: auto)
      IMAGE_DTYPE: "auto" | "float16" | "bfloat16" | "float32" (default: auto)
      IMAGE_OUTPUT_DIR: output directory (default: storage/outputs)
    """

    def __init__(self, model_path: Optional[str] = None):
        self.model_path = model_path or os.getenv("IMAGE_MODEL_PATH", "storage/models/sd-turbo")
        self.model_id = os.getenv("IMAGE_MODEL_ID", "stabilityai/sd-turbo")
        self.model_type = os.getenv("IMAGE_MODEL_TYPE", "sdturbo").lower()
        self.local_only = os.getenv("IMAGE_LOCAL_ONLY", "false").lower() == "true"
        self.enable_diffusers = os.getenv("IMAGE_ENABLE_DIFFUSERS", "true").lower() == "true"
        self.device_pref = os.getenv("IMAGE_DEVICE", "auto").lower()
        self.dtype_pref = os.getenv("IMAGE_DTYPE", "auto").lower()
        self.output_dir = Path(os.getenv("IMAGE_OUTPUT_DIR", "storage/outputs"))

        self._pipe = None
        self._diffusers_ready = bool(torch is not None and StableDiffusionPipeline is not None)

    def _resolve_device(self) -> str:
        if torch is None:
            return "cpu"
        if self.device_pref in ("cpu", "cuda"):
            return self.device_pref
        return "cuda" if torch.cuda.is_available() else "cpu"

    def _resolve_dtype(self, device: str):
        if torch is None:
            return None
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

        if not self.enable_diffusers or not self._diffusers_ready:
            return

        device = self._resolve_device()
        dtype = self._resolve_dtype(device)
        model_path_obj = Path(self.model_path)

        # Prefer a model directory under storage for persistence across rebuilds.
        if model_path_obj.exists():
            model_source = str(model_path_obj)
            local_files_only = True
            cache_dir = None
        else:
            model_source = self.model_id
            local_files_only = self.local_only
            cache_dir = str(self.output_dir.parent / ".hf-cache")

        if self.model_type == "sdxl":
            pipe = StableDiffusionXLPipeline.from_pretrained(
                model_source,
                local_files_only=local_files_only,
                torch_dtype=dtype,
                cache_dir=cache_dir,
            )
        else:
            pipe = StableDiffusionPipeline.from_pretrained(
                model_source,
                local_files_only=local_files_only,
                torch_dtype=dtype,
                cache_dir=cache_dir,
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

    def _render_fallback(self, prompt: str, width: int, height: int, out_path: Path) -> None:
        # Lightweight fallback image for environments without local model or heavy ML deps.
        image = Image.new("RGB", (width, height), color=(24, 28, 36))
        draw = ImageDraw.Draw(image)

        for y in range(height):
            shade = int(24 + (y / max(height, 1)) * 60)
            draw.line([(0, y), (width, y)], fill=(shade, shade + 8, shade + 16))

        title = "Generated (Fallback)"
        max_chars = 120
        text = prompt[:max_chars] + ("..." if len(prompt) > max_chars else "")
        font = ImageFont.load_default()

        draw.rectangle([(16, 16), (width - 16, 100)], fill=(0, 0, 0, 120))
        draw.text((24, 24), title, fill=(255, 255, 255), font=font)
        draw.text((24, 52), text, fill=(220, 230, 245), font=font)

        image.save(out_path)

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

        ts = int(time.time())
        fname = f"img_{ts}.png"
        out_path = self.output_dir / fname

        if self._pipe is None:
            self._render_fallback(prompt=prompt, width=int(width), height=int(height), out_path=out_path)
            return str(out_path)

        generator = None
        if seed is not None:
            device = self._resolve_device()
            generator = torch.Generator(device=device).manual_seed(int(seed))

        # SDXL uses slightly different defaults; keep args compatible.
        final_steps = int(steps)
        final_guidance = float(guidance_scale)

        if self.model_type == "sdturbo":
            # SD-Turbo works best with very low step count and no CFG guidance.
            final_steps = max(1, min(int(steps), 4))
            final_guidance = 0.0

        common_kwargs = dict(
            prompt=prompt,
            num_inference_steps=final_steps,
            guidance_scale=final_guidance,
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

        image.save(out_path)

        return str(out_path)
