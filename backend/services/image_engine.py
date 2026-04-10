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
