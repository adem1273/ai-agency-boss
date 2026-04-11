import json
import logging
import os
from pathlib import Path
from typing import Any, Dict, Optional

# Local-only Llama-3 inference via llama-cpp-python and GGUF.
# NOTE: This loads the model from local disk; no external API calls.
#
# Expected GGUF file:
#   /app/storage/models/Meta-Llama-3-8B-Instruct-Q4_K_M.gguf
#
# Environment knobs:
#   AI_MODEL_PATH: override model file path
#   AI_N_CTX: context length (default: 4096)
#   AI_N_THREADS: CPU threads used by llama.cpp (default: cpu_count-1)
#   AI_N_GPU_LAYERS: GPU layers offloaded (default: 0)
#   AI_TEMPERATURE: generation temperature (default: 0.7)
#   AI_TOP_P: nucleus sampling (default: 0.9)
#   AI_MAX_TOKENS: max generated tokens (default: 700)

try:
    from llama_cpp import Llama
except Exception:
    Llama = None


logger = logging.getLogger(__name__)


class AIManager:
    def __init__(self, model_path: Optional[str] = None):
        env_model_path = os.getenv("AI_MODEL_PATH", "").strip()
        self.model_path = model_path or env_model_path or self._resolve_default_model_path()
        self.enable_local_llm = os.getenv("AI_ENABLE_LOCAL_LLM", "true").lower() == "true"
        self.n_ctx = int(os.getenv("AI_N_CTX", "4096"))
        self.n_threads = int(os.getenv("AI_N_THREADS", str(max(1, (os.cpu_count() or 2) - 1))))
        self.n_gpu_layers = int(os.getenv("AI_N_GPU_LAYERS", "0"))
        self.temperature = float(os.getenv("AI_TEMPERATURE", "0.7"))
        self.top_p = float(os.getenv("AI_TOP_P", "0.9"))
        self.max_tokens = int(os.getenv("AI_MAX_TOKENS", "700"))

        self._llm = None
        self._llama_ready = Llama is not None

    def _resolve_default_model_path(self) -> str:
        candidates = [
            "/app/storage/models/Meta-Llama-3-8B-Instruct-Q4_K_M.gguf",
            "storage/models/Meta-Llama-3-8B-Instruct-Q4_K_M.gguf",
        ]
        for candidate in candidates:
            if Path(candidate).exists():
                return str(Path(candidate).resolve())
        return candidates[0]

    def _load(self) -> None:
        if self._llm is not None:
            return

        if not self.enable_local_llm or not self._llama_ready:
            return

        model_file = Path(self.model_path).resolve()
        if not model_file.exists():
            logger.warning("GGUF model file not found at %s", model_file)
            return

        self._llm = Llama(
            model_path=str(model_file),
            n_ctx=self.n_ctx,
            n_threads=self.n_threads,
            n_gpu_layers=self.n_gpu_layers,
            verbose=False,
        )

    def _extract_json(self, text: str) -> Dict[str, Any]:
        start = text.find("{")
        end = text.rfind("}")
        if start == -1 or end == -1 or end <= start:
            raise ValueError("Model output did not contain a JSON object.")

        json_text = text[start : end + 1]
        try:
            return json.loads(json_text)
        except json.JSONDecodeError as exc:
            raise ValueError(f"Invalid JSON produced by model: {exc}") from exc

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

        if self._llm is None:
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

        try:
            out = self._llm(
                prompt,
                max_tokens=self.max_tokens,
                temperature=self.temperature,
                top_p=self.top_p,
                stop=["```"],
            )
            text = out["choices"][0]["text"]
            return self._extract_json(text)
        except Exception as exc:
            logger.exception("Local llama.cpp generation failed: %s", exc)
            return self._fallback_strategy(business_description)
