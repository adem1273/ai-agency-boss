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
