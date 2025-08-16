import logging
import logging.config
from pathlib import Path

import yaml


def configure_logging():
    log_dir = Path("./log")
    log_dir.mkdir(exist_ok=True)
    with open("logging.yaml", "r") as f:
        logging.config.dictConfig(yaml.safe_load(f))
