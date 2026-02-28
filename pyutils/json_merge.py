#!/usr/bin/env python3
# Merge two JSON files: apply source keys on top of target.
#
# Reads both files, performs a shallow `dict.update()` (source wins on
# key conflicts), and writes the result back to the target file.
#
# Args
# ----
# - `source`
#     Path to the JSON file with keys to apply.
# - `target`
#     Path to the JSON file to update in-place.
#
# Returns
# -------
# (No-Returns)
import json
import sys


def main():
    """
    Merge source JSON keys into target JSON file.

    Args
    ----
    (No-Args)

    Returns
    -------
    (No-Returns)
    """
    source_path = sys.argv[1]
    target_path = sys.argv[2]

    with open(source_path) as f:
        source = json.load(f)

    with open(target_path) as f:
        target = json.load(f)

    target.update(source)

    with open(target_path, "w") as f:
        json.dump(target, f, indent=4)


if __name__ == "__main__":
    main()
