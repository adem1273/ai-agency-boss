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

try:
    from transformers import AutoTokenizer, AutoModelForCausalLM
    import torch
except Exception:
    AutoTokenizer = None
    AutoModelForCausalLM = None
    torch = None


class AIManager:
    def __init__(self, model_path: Optional[str] = None):
        self.model_path = model_path or os.getenv("AI_MODEL_PATH", "storage/models/llama3")
        self.enable_transformers = os.getenv("AI_ENABLE_TRANSFORMERS", "true").lower() == "true"
        self.device_pref = os.getenv("AI_DEVICE", "auto")
        self.dtype_pref = os.getenv("AI_DTYPE", "auto")

        self._tokenizer = None
        self._model = None
        self._transformers_ready = bool(
            torch is not None and AutoTokenizer is not None and AutoModelForCausalLM is not None
        )

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
        if self._model is not None and self._tokenizer is not None:
            return

        if not self.enable_transformers or not self._transformers_ready:
            return

        if not os.path.exists(self.model_path):
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

    def _fallback_strategy(self, business_description: str) -> Dict[str, Any]:
        text = business_description.strip()
        short = text[:140] + ("..." if len(text) > 140 else "")
        return {
            "target_audience": [
                {
                    "segment": "Core buyers",
                    "reason": "Value proposition fits convenience and quality seekers.",
                },
                {
                    "segment": "Social discovery users",
                    "reason": "Likely to discover brands via short-form video and creator content.",
                },
                {
                    "segment": "Budget-conscious comparers",
                    "reason": "Responds to clear pricing, bundles, and limited-time offers.",
                },
            ],
            "slogan_suggestions": [
                "Make every click count.",
                "Built for your next big win.",
                "Fast value, real results.",
                "From idea to impact.",
                "Smarter moves, better outcomes.",
            ],
            "campaign_strategy": {
                "business_summary": short,
                "channels": ["instagram", "tiktok", "google search"],
                "creative_angles": [
                    "before-after transformation",
                    "customer proof and testimonials",
                    "behind-the-scenes trust building",
                ],
                "seven_day_plan": [
                    "Day 1: Define offer and hero message",
                    "Day 2: Produce 3 creatives and 2 headlines",
                    "Day 3: Launch test campaigns",
                    "Day 4: Review CTR/CPC and pause weak ads",
                    "Day 5: Scale best audience by 20% budget",
                    "Day 6: Add retargeting creatives",
                    "Day 7: Summarize learnings and next sprint",
                ],
            },
        }

    def generate_strategy(self, business_description: str) -> Dict[str, Any]:
        """
        Given a business description, produce a JSON report including:
        - target_audience
        - slogan_suggestions
        - campaign_strategy

        Returns a Python dict (already parsed JSON).
        """
        self._load()

        if self._model is None or self._tokenizer is None:
            return self._fallback_strategy(business_description)

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
