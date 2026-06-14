from pydantic import (
    BaseModel,
    field_validator,
    model_validator,
    Field,
    ConfigDict
)


class AnalysisQueryParameters(BaseModel):
    """Shared custom base model for all notebook's query parameters"""

    model_config = ConfigDict(
        frozen=True
    )
