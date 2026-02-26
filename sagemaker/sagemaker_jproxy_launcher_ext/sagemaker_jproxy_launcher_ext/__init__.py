# Copyright Jianfei Gao. All Rights Reserved.
# Originally by Giuseppe Angelo Porcelli (aws-samples/sagemaker-codeserver).
# SPDX-License-Identifier: MIT-0
import json
from pathlib import Path

from ._version import __version__


HERE = Path(__file__).parent.resolve()


with open(HERE / "labextension" / "package.json") as fid:
    data = json.load(fid)


def _jupyter_labextension_paths():
    return [{"src": "labextension", "dest": data["name"]}]
