import argparse
import logging
from pathlib import Path
import pandas as pd

from connectors.sink.azure_sql_sink_connector import AzureSQLSinkConnector
from transformations.domain_transformer import DomainTransformer
from helpers.logging_helper import LoggingHelper
from connectors.sources.azure_sql_source_connector import AzureSQLSourceConnector


class DomainCommonrefRunner:
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

        self.azure_sql_source_connector = AzureSQLSourceConnector(
            app_config_name=app_config_name,
            server_name="source-database-server",
            database_name="source-database-name",
            username="source-database-readonly-username",
            password="source-database-readonly-password",
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

        self.queries_path = Path("resources/domain_resources/queries")

    def execute_query_file(self, sql_connection, query_file: Path) -> pd.DataFrame:
        self.logger.info("Executing query file: %s", query_file.name)

        with open(query_file, "r", encoding="utf-8") as file:
            query = file.read()

        df = pd.read_sql(query, sql_connection)

        transformer = DomainTransformer()
        df = transformer.transform(df)

        self.logger.info(
            "Completed query file: %s | rows=%s | columns=%s",
            query_file.name,
            len(df),
            len(df.columns),
        )

        return df

    def run(self) -> None:
        self.logger.info("Starting commonref runner")

        sql_connection = None

        try:
            sql_connection = self.azure_sql_source_connector.get_sql_connection()

            query_files = list(self.queries_path.glob("*.sql"))

            for query_file in query_files:
                df = self.execute_query_file(sql_connection, query_file)

                target_table_name = query_file.stem.lower()

                self.azure_sql_sink_connector.write_dataframe(
                    df=df,
                    schema_name="dbo",
                    table_name=target_table_name,
                )

            self.logger.info("Commonref runner completed successfully")

        except Exception as exc:
            self.logger.exception("Commonref runner failed: %s", exc)
            raise

        finally:
            if sql_connection:
                sql_connection.close()
                self.logger.info("Source SQL connection closed")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--env", required=True, help="Environment to run")
    parser.add_argument("--ac", required=True, help="App config name")
    parser.add_argument("--settings-path", required=False, help="Local settings path")

    args = parser.parse_args()

    runner = DomainCommonrefRunner(
        environment=args.env,
        app_config_name=args.ac,
        settings_path=args.settings_path,
    )

    runner.run()
