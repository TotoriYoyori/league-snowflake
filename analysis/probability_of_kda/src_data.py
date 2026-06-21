import os 

import pandas as pd
from snowflake.snowpark import Session
import streamlit as st

# ----- Get connection
@st.cache_resource
def get_session() -> Session:
    conn = st.connection(
        "snowflake", 
        ttl=os.getenv("SNOWFLAKE_CONNECTION_TTL")
    )
    
    return conn.session()


# ----- Get data 
@st.cache_data
def get_data(_session: Session, query: str) -> pd.DataFrame:
    return _session.sql(query).to_pandas()
    