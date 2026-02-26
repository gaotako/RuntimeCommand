# Copyright Jianfei Gao. All Rights Reserved.
# Originally by Giuseppe Angelo Porcelli (aws-samples/sagemaker-codeserver).
# SPDX-License-Identifier: MIT-0
import json
from pathlib import Path


__all__ = ["__version__"]


def _fetchVersion() -> str:
    """
    Fetch the version from the package.json file.

    Args
    ----
    (No-Args)

    Returns
    -------
    - `version`
        Version of the package.
    """
    HERE = Path(__file__).parent.resolve()

    for settings in HERE.rglob("package.json"):
        try:
            with settings.open() as f:
                return json.load(f)["version"]
        except FileNotFoundError:
            pass

    raise FileNotFoundError(f"Could not find package.json under dir {HERE!s}")


__version__ = _fetchVersion()
