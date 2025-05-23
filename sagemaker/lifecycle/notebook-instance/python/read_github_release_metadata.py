import json
import sys
from typing import Any, Mapping, TextIO


def flatten_github_release_metadata(raw: Any, key_prefix: str | None = None) -> Mapping[str, str]:
    r"""
    Flatten Github release metadta.

    Args
    ----
    - raw
        Raw metadata.

    Returns
    -------
    - processed
        Processed metadata.
    """
    processed = {}
    if isinstance(raw, dict):
        for key, child in raw.items():
            processed.update(
                flatten_github_release_metadata(
                    child, key_prefix=f"{key_prefix:s}.{key:s}" if key_prefix is not None else key
                )
            )
    elif isinstance(raw, list):
        processed[f"{key_prefix:s}.#" if key_prefix is not None else "#"] = json.dumps(str(len(raw)))[1:-1]
        for i, child in enumerate(raw):
            key = str(i)
            processed.update(
                flatten_github_release_metadata(
                    child, key_prefix=f"{key_prefix:s}.{key:s}" if key_prefix is not None else key
                )
            )
    else:
        processed[key_prefix] = json.dumps(str(raw) if raw is not None else "")[1:-1]
    return processed


def read_github_release_metadata(github_release_metadata_msg: str) -> Mapping[str, str]:
    r"""
    Read Github release metadata.

    Args
    ----
    - github_release_metadata_msg
        Github release metadata message (of latest release).

    Returns
    -------
    - github_release_metadata
        Release metadata.

    Notes
    -----
    Release metadata may have multiple levels, and we will collapse them all to one level.
    """
    github_release_metadata_raw = json.loads(github_release_metadata_msg)
    github_release_metadata_processed = flatten_github_release_metadata(github_release_metadata_raw)
    return github_release_metadata_processed


def show_github_release_metadata(
    github_release_metadata: Mapping[str, str],
    /,
    *,
    sep_unit: str | None = None,
    output: TextIO | None = None,
) -> None:
    r"""
    Show resource metadata.

    Args
    ----
    - github_release_metadata
        Release metadata.
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
    maxlen_key = max(len(key) for key in github_release_metadata)
    for key, value in github_release_metadata.items():
        line = key + sep_unit * (maxlen_key - len(key) + 1) + value
        print(line, file=output)


if __name__ == "__main__":
    show_github_release_metadata(read_github_release_metadata(sys.argv[1]))
