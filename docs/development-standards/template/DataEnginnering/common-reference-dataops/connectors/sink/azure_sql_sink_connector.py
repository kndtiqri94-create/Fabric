import logging
import re

import pandas as pd
import pyodbc
from simple_azure_utils import load_setting


class AzureSQLSinkConnector:
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
        connection_string = (
            f"DRIVER={self.driver};"
            f"SERVER={self.server_name};"
            f"DATABASE={self.database_name};"
            f"UID={self.username};"
            f"PWD={self.password}"
        )

        return pyodbc.connect(connection_string)

    @staticmethod
    def clean_column_name(column_name: str, position: int) -> str:
        column_name = str(column_name).strip().lower()

        if not column_name or column_name == "nan":
            column_name = f"column_{position}"

        column_name = re.sub(r"[^a-zA-Z0-9_]", "_", column_name)
        column_name = re.sub(r"_+", "_", column_name).strip("_")

        if not column_name:
            column_name = f"column_{position}"

        return column_name

    def clean_dataframe_columns(self, df: pd.DataFrame) -> pd.DataFrame:
        df = df.copy()

        cleaned_columns = []
        used_columns = {}

        for index, column in enumerate(df.columns, start=1):
            cleaned_column = self.clean_column_name(column, index)

            if cleaned_column in used_columns:
                used_columns[cleaned_column] += 1
                cleaned_column = f"{cleaned_column}_{used_columns[cleaned_column]}"
            else:
                used_columns[cleaned_column] = 1

            cleaned_columns.append(cleaned_column)

        df.columns = cleaned_columns

        return df

    @staticmethod
    def safe_sql_value(value):
        """
        Converts every value safely for VARCHAR(MAX) insert.

        - NaN becomes None
        - NaT becomes None
        - None stays None
        - Everything else becomes string
        """

        if value is None:
            return None

        try:
            if pd.isna(value):
                return None
        except Exception:
            pass

        return str(value)

    @staticmethod
    def table_exists(
        cursor: pyodbc.Cursor,
        schema_name: str,
        table_name: str,
    ) -> bool:
        cursor.execute(
            """
            SELECT COUNT(1)
            FROM INFORMATION_SCHEMA.TABLES
            WHERE TABLE_SCHEMA = ?
              AND TABLE_NAME = ?
            """,
            schema_name,
            table_name,
        )

        return cursor.fetchone()[0] > 0

    @staticmethod
    def create_table_sql(
        df: pd.DataFrame,
        schema_name: str,
        table_name: str,
    ) -> str:
        column_definitions = []

        for column in df.columns:
            column_definitions.append(f"[{column}] VARCHAR(MAX) NULL")

        columns_sql = ",\n    ".join(column_definitions)

        return f"""
        CREATE TABLE [{schema_name}].[{table_name}] (
            {columns_sql}
        )
        """

    @staticmethod
    def build_insert_sql(
        df: pd.DataFrame,
        schema_name: str,
        table_name: str,
    ) -> str:
        columns = ", ".join([f"[{column}]" for column in df.columns])
        placeholders = ", ".join(["?" for _ in df.columns])

        return f"""
        INSERT INTO [{schema_name}].[{table_name}]
        ({columns})
        VALUES ({placeholders})
        """

    def build_safe_rows(self, df: pd.DataFrame) -> list[tuple]:
        rows = []

        for row in df.itertuples(index=False, name=None):
            safe_row = tuple(self.safe_sql_value(value) for value in row)
            rows.append(safe_row)

        return rows

    def write_dataframe(
        self,
        df: pd.DataFrame,
        schema_name: str,
        table_name: str,
    ) -> None:
        sql_connection = None

        try:
            if df.empty:
                self.logger.warning(
                    "DataFrame is empty. Skipping write to table: %s.%s",
                    schema_name,
                    table_name,
                )
                return

            self.logger.info(
                "Starting write to SQL table: %s.%s | rows=%s | columns=%s",
                schema_name,
                table_name,
                len(df),
                len(df.columns),
            )

            df = self.clean_dataframe_columns(df)

            sql_connection = self.get_sql_connection()
            cursor = sql_connection.cursor()
            cursor.fast_executemany = False

            if not self.table_exists(cursor, schema_name, table_name):
                self.logger.info(
                    "Table does not exist. Creating table: %s.%s",
                    schema_name,
                    table_name,
                )

                create_sql = self.create_table_sql(
                    df=df,
                    schema_name=schema_name,
                    table_name=table_name,
                )

                cursor.execute(create_sql)
                sql_connection.commit()

                self.logger.info(
                    "Successfully created table: %s.%s",
                    schema_name,
                    table_name,
                )

            insert_sql = self.build_insert_sql(
                df=df,
                schema_name=schema_name,
                table_name=table_name,
            )

            rows = self.build_safe_rows(df)

            for row_number, row in enumerate(rows, start=1):
                try:
                    cursor.execute(insert_sql, row)
                except Exception as row_exc:
                    self.logger.exception(
                        "Failed inserting row_number=%s | row=%s | error=%s",
                        row_number,
                        row,
                        row_exc,
                    )
                    raise

            sql_connection.commit()

            self.logger.info(
                "Successfully wrote DataFrame to SQL table: %s.%s | rows=%s",
                schema_name,
                table_name,
                len(df),
            )

        except Exception as exc:
            if sql_connection:
                sql_connection.rollback()

            self.logger.exception(
                "Failed writing DataFrame to SQL table: %s.%s | error=%s",
                schema_name,
                table_name,
                exc,
            )
            raise

        finally:
            if sql_connection:
                sql_connection.close()
                self.logger.info("Sink SQL connection closed")