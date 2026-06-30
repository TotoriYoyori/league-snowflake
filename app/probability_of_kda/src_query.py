from dataclasses import dataclass


@dataclass
class ProbabilityOfKDAQuery:
    # ----- Base query
    template: str = """
    SELECT 
        MINUTE, 
        KILLS, 
        DEATHS, 
        ASSISTS{kda_col}
    FROM LEAGUE_RECORDS.SILVER.PLAYER_INTERVAL_SILVER
    ORDER BY MINUTE {order_direction}
    """
    # ----- Overidable options
    stats_options: list[str] = ["KILLS", "DEATHS", "ASSISTS", "KDA_RATIO"]
    order_direction: str = "ASC"
    include_kda_ratio: bool = True

    def build(self) -> str:
        kda_col = ""
        if self.include_kda_ratio:
            kda_col = (
                ",\n    COALESCE(ROUND((KILLS + ASSISTS) / NULLIF(DEATHS, 0), 2), "
                "KILLS + ASSISTS) AS KDA_RATIO"
            )
    
        return self.template.format(
            kda_col=kda_col,
            order_direction=self.order_direction,
        )