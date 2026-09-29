import logging
import pandas as pd

from helpers.audit_helper import AuditHelper


class DomainTransformer:
    def __init__(self) -> None:
        self.logger = logging.getLogger(self.__class__.__name__)

    def transform(self, df: pd.DataFrame) -> pd.DataFrame:
        self.logger.info("Starting DomainTransformer.transform")

        try:
            final_df = self._build_final_output_dataframe(df)

            self.logger.info(
                "DomainTransformer.transform completed successfully. Rows: %s",
                len(final_df),
            )

            return final_df

        except Exception as exc:
            self.logger.exception(
                "DomainTransformer.transform failed: %s",
                exc,
            )
            raise

    def _build_final_output_dataframe(self, df: pd.DataFrame) -> pd.DataFrame:
        df = AuditHelper.add_audit_columns(df)
        return df
