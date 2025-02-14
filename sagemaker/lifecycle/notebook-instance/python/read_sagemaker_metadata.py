import json
import sys
from typing import Mapping, TextIO
from pathlib import Path


PATH_RESOURCR_METADATA = Path("/opt/ml/metadata/resource-metadata.json")


def read_resource_metadata(path: Path | None = None) -> Mapping[str, str]:
    r"""
    Read resource metadata.

    Args
    ----
    - path
        Path to read resource metadata from.
        By default, it is the SageMaker instance resource metadata path.

    Returns
    -------
    - resource_metadata
        Resource metadata.

    Notes
    -----
    Resource metadata only has ARN and name, and we further extract metadata item from ARN.
    """
    if PATH_RESOURCR_METADATA.exists():
        with open(PATH_RESOURCR_METADATA, "r") as file:
            resource_metadata = json.load(file)
        arn = str(resource_metadata["ResourceArn"])
        resource_name = str(resource_metadata["ResourceName"])
        _, partition, service, region, account_id, suffix = arn.split(":")
        resource_type, resource_id = suffix.split("/", maxsplit=1)
        return {
            "arn": arn,
            "resource_name": resource_name,
            "partition": partition,
            "account_id": account_id,
            "region": region,
            "service": service,
            "resource_type": resource_type,
            "resource_id": resource_id,
        }
    else:
        return {}


def show_resource_metadata(
    resource_metadata: Mapping[str, str],
    /,
    *,
    sep_unit: str | None = None,
    output: TextIO | None = None,
) -> None:
    r"""
    Show resource metadata.

    Args
    ----
    - resource_metadata
        Resource metadata to be shown.
    - sep_unit
        Unit character for separator between metadata key and value.
        It must be a single ASCII character, if violated, it will only take the first ASCII
        character from the string.
        By default, whitespace is used.

    Returns
    -------
    (No-Returns)
    """
    sep_unit_ascii_code = ord(sep_unit[0]) if sep_unit else ord(" ")
    sep_unit_ = chr(sep_unit_ascii_code) if sep_unit_ascii_code else " "
    output_ = output if output else sys.stdout
    maxlen_key = max(len(key) for key in resource_metadata)
    for key, value in resource_metadata.items():
        line = key + sep_unit_ * (maxlen_key - len(key) + 1) + value
        print(line)


if __name__ == "__main__":
    show_resource_metadata(read_resource_metadata())
