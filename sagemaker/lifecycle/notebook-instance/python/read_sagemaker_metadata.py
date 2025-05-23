import json
import sys
from typing import Mapping, TextIO


PATH_RESOURCR_METADATA = "/opt/ml/metadata/resource-metadata.json"


def read_resource_metadata(path: str | None = None) -> Mapping[str, str]:
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
    path = path if path is not None else PATH_RESOURCR_METADATA
    if path.exists():
        with open(path, "r") as file:
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
    - output
        Output direction.

    Returns
    -------
    (No-Returns)
    """
    sep_unit_ascii_code = ord(sep_unit[0]) if sep_unit else ord(" ")
    sep_unit = chr(sep_unit_ascii_code) if sep_unit_ascii_code is not None else " "
    output = output if output is not None else sys.stdout
    maxlen_key = max(len(key) for key in resource_metadata)
    for key, value in resource_metadata.items():
        line = key + sep_unit * (maxlen_key - len(key) + 1) + value
        print(line, file=output)


if __name__ == "__main__":
    show_resource_metadata(read_resource_metadata(sys.argv[1] if len(sys.argv) > 1 else None))
