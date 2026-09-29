import logging
import pyodbc
from simple_azure_utils import load_setting


class AzureSQLSourceConnector:
    def __init__(
        self,
        server_name: str,
        database_name: str,
        username: str,
        password: str,
        app_config_name: str = None,
        environment: str = None,
        settings_path: str = None,
    ) -> None:
        self.logger = logging.getLogger(self.__class__.__name__)

        self.server_name = load_setting(
            server_name,
            app_config_name=app_config_name,
            settings_path=settings_path,
            label=environment,
        )
        self.database_name = load_setting(
            database_name,
            app_config_name=app_config_name,
            settings_path=settings_path,
            label=environment,
        )
        self.username = load_setting(
            username,
            app_config_name=app_config_name,
            settings_path=settings_path,
            label=environment,
        )
        self.password = load_setting(
            password,
            app_config_name=app_config_name,
            settings_path=settings_path,
            label=environment,
        )

        self.driver = "{ODBC Driver 17 for SQL Server}"

    def get_sql_connection(self) -> pyodbc.Connection:
        try:
            self.logger.info(
                "Connecting to Azure SQL Database: %s on server: %s",
                self.database_name,
                self.server_name,
            )

            connection_string = (
                f"DRIVER={self.driver};"
                f"SERVER={self.server_name};"
                f"DATABASE={self.database_name};"
                f"UID={self.username};"
                f"PWD={self.password}"
            )

            sql_connection = pyodbc.connect(connection_string)

            self.logger.info(
                "Successfully connected to Azure SQL Database: %s",
                self.database_name,
            )

            return sql_connection

        except Exception as exc:
            self.logger.exception(
                "Failed connecting to Azure SQL Database: %s on server: %s | error=%s",
                self.database_name,
                self.server_name,
                exc,
            )
            raise