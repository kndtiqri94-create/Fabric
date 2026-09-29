import hashlib
import pandas as pd
from datetime import datetime, timezone


class AuditHelper:

    @staticmethod
    def get_pipeline_run_time() -> datetime:
        return datetime.now(timezone.utc)

    @staticmethod
    def create_audit_digest(row: pd.Series) -> str:

        row_values = []

        for value in row:
            if pd.isna(value):
                clean_value = ""
            else:
                clean_value = str(value).strip().lower()

            row_values.append(clean_value)

        row_string = "|".join(row_values)

        return hashlib.sha256(row_string.encode("utf-8")).hexdigest()

    @staticmethod
    def add_audit_columns(df: pd.DataFrame) -> pd.DataFrame:
        df = df.copy()

        pipeline_run_time = AuditHelper.get_pipeline_run_time()

        df["audit_digest"] = df.apply(
            lambda row: AuditHelper.create_audit_digest(row),
            axis=1
        )

        df["pipeline_run_time"] = pipeline_run_time

        return df