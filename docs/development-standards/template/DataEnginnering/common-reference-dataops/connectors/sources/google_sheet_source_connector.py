import json
import logging
from typing import Optional

import gspread
import pandas as pd
from google.oauth2.service_account import Credentials
from simple_azure_utils import load_setting


class GoogleSheetSourceConnector:
    def __init__(
        self,
        google_service_account: str,
        spreadsheet_id: str,
        app_config_name: Optional[str] = None,
        environment: Optional[str] = None,
        settings_path: Optional[str] = None,
    ) -> None:
        self.logger = logging.getLogger(self.__class__.__name__)

        self.google_service_account_json = load_setting(
            google_service_account,
            app_config_name=app_config_name,
            settings_path=settings_path,
            label=environment,
        )

        self.spreadsheet_id = spreadsheet_id

        self.scopes = [
            "https://www.googleapis.com/auth/spreadsheets.readonly"
        ]

    def get_google_sheet_connection(self) -> gspread.Client:
        try:
            self.logger.info("Connecting to Google Sheets")

            if not self.google_service_account_json:
                raise ValueError("Google service account JSON is empty or missing")

            service_account_info = json.loads(self.google_service_account_json)

            credentials = Credentials.from_service_account_info(
                service_account_info,
                scopes=self.scopes,
            )

            client = gspread.authorize(credentials)

            self.logger.info("Successfully connected to Google Sheets")

            return client

        except Exception as exc:
            self.logger.exception(
                "Failed connecting to Google Sheets | error=%s",
                exc,
            )
            raise

    def read_worksheet(self, worksheet_name: str) -> pd.DataFrame:
        try:
            self.logger.info(
                "Reading worksheet '%s' from spreadsheet: %s",
                worksheet_name,
                self.spreadsheet_id,
            )

            client = self.get_google_sheet_connection()

            spreadsheet = client.open_by_key(self.spreadsheet_id)
            worksheet = spreadsheet.worksheet(worksheet_name)

            records = worksheet.get_all_records()
            df = pd.DataFrame(records)

            self.logger.info(
                "Successfully loaded %s rows and %s columns from worksheet '%s'",
                len(df),
                len(df.columns),
                worksheet_name,
            )

            return df

        except Exception as exc:
            self.logger.exception(
                "Failed reading worksheet '%s' | error=%s",
                worksheet_name,
                exc,
            )
            raise

    @staticmethod
    def clean_dataframe_columns(df: pd.DataFrame) -> pd.DataFrame:
        df = df.copy()

        df.columns = (
            df.columns
            .str.strip()
            .str.lower()
            .str.replace(" ", "_", regex=False)
            .str.replace("-", "_", regex=False)
        )

        return df