import argparse
import json
import logging
from pathlib import Path

import pandas as pd

from connectors.sink.azure_sql_sink_connector import AzureSQLSinkConnector
from connectors.sources.google_sheet_source_connector import GoogleSheetSourceConnector
from helpers.logging_helper import LoggingHelper
from transformations.domain_transformer import DomainTransformer


class DomainGoogleSheetRunner:
    def __init__(
        self,
        environment: str,
        app_config_name: str,
        settings_path: str | None = None,
    ) -> None:
        LoggingHelper.setup_logging()
        self.logger = logging.getLogger(self.__class__.__name__)

        self.environment = environment
        self.app_config_name = app_config_name
        self.settings_path = settings_path

        self.google_sheet_config_path = Path(
            "resources/domain_resources/google_sheets/google_sheet_config.json"
        )

        self.google_sheet_config = self.load_google_sheet_config()

        self.google_sheet_source_connector = GoogleSheetSourceConnector(
            app_config_name=app_config_name,
            google_service_account=self.google_sheet_config[
                "google_service_account_setting_name"
            ],
            spreadsheet_id=self.google_sheet_config["spreadsheet_id"],
            environment=environment,
            settings_path=settings_path,
        )

        self.azure_sql_sink_connector = AzureSQLSinkConnector(
            app_config_name=app_config_name,
            server_name="sink-database-server",
            database_name="sink-database-name",
            username="sink-database-username",
            password="sink-database-password",
            environment=environment,
            settings_path=settings_path,
        )

    def load_google_sheet_config(self) -> dict:
        try:
            self.logger.info(
                "Loading Google Sheet config from: %s",
                self.google_sheet_config_path,
            )

            with open(self.google_sheet_config_path, "r", encoding="utf-8") as file:
                config = json.load(file)

            self.logger.info("Google Sheet config loaded successfully")

            return config

        except Exception as exc:
            self.logger.exception(
                "Failed loading Google Sheet config | path=%s | error=%s",
                self.google_sheet_config_path,
                exc,
            )
            raise

    def process_worksheet(self, worksheet_config: dict) -> pd.DataFrame:
        worksheet_name = worksheet_config["worksheet_name"]
        target_schema = worksheet_config.get("target_schema", "dbo")
        target_table = worksheet_config["target_table"]

        self.logger.info(
            "Processing worksheet '%s' into table %s.%s",
            worksheet_name,
            target_schema,
            target_table,
        )

        df = self.google_sheet_source_connector.read_worksheet(
            worksheet_name=worksheet_name
        )

        transformer = DomainTransformer()
        df = transformer.transform(df)

        self.azure_sql_sink_connector.write_dataframe(
            df=df,
            schema_name=target_schema,
            table_name=target_table,
        )

        self.logger.info(
            "Successfully written worksheet '%s' to %s.%s | rows=%s | columns=%s",
            worksheet_name,
            target_schema,
            target_table,
            len(df),
            len(df.columns),
        )

        return df

    def run(self) -> None:
        self.logger.info("Starting domain Google Sheet runner")

        try:
            worksheets = self.google_sheet_config["worksheets"]

            for worksheet_config in worksheets:
                self.process_worksheet(worksheet_config)

            self.logger.info(
                "Domain Google Sheet runner completed successfully"
            )

        except Exception as exc:
            self.logger.exception(
                "Domain Google Sheet runner failed: %s",
                exc,
            )
            raise


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--env", required=True, help="Environment to run")
    parser.add_argument("--ac", required=True, help="App config name")
    parser.add_argument("--settings-path", required=False, help="Local settings path")

    args = parser.parse_args()

    runner = DomainGoogleSheetRunner(
        environment=args.env,
        app_config_name=args.ac,
        settings_path=args.settings_path,
    )

    runner.run()
