import logging


class LoggingHelper:
    _initialized = False

    @classmethod
    def setup_logging(cls) -> None:
        if cls._initialized:
            return

        logging.basicConfig(
            level=logging.INFO,
            format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
        )

        logging.getLogger("azure.identity").setLevel(logging.ERROR)
        logging.getLogger("azure.core.pipeline").setLevel(logging.ERROR)

        cls._initialized = True
