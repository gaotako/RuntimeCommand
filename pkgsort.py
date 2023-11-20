# Import Python packages.
import argparse
import json
from typing import Optional, Sequence


def main(terms: Optional[Sequence[str]], /) -> None:
    r"""
    Executable application.

    Args
    ----
    - terms
        Terminal keywords.

    Returns
    -------
    """
    # YAML configuration is an essential argument for all applications.
    parser = argparse.ArgumentParser(description="Package Sorting by Depenedency.")
    parser.add_argument("path", type=str, help="Dependency tree JSON file.")
    args = parser.parse_args(terms)

    # Load json file.
    with open(args.path, "r") as file:
        # Load raw dependency tree.
        dependencies = json.load(file)
    linkin = {}
    linkout = {}
    focus = "package_name"
    while len(dependencies) > 0:
        # Take a package away from cache and parse its info.
        info = dependencies.pop(0)
        dependencies.extend(info["dependencies"])
        for name in [info[focus]] + [
            subinfo[focus] for subinfo in info["dependencies"]
        ]:
            # We will track dependency tree in both direction separately.
            for link in [linkin, linkout]:
                # Add every currently involved package into tracking tree.
                if name not in link:
                    # Add a package to tracking tree by creating an empty adjacency set for it.
                    link[name] = set([])
        for subinfo in info["dependencies"]:
            # Build link from each dependent package to parsed package.
            linkout[info[focus]].add(subinfo[focus])
            linkout[subinfo[focus]].add(info[focus])

    # Scan for the bottom-level packages.
    bottom = [name for name, neighbors in linkin if len(neighbors) == 0]
    levels = {name: 0 for name in bottom}

    # Traverse the tree from bottom level following dependency direction..
    queue = [name for name in bottom]


# Main-program-only operations which is not included in library module operations.
if __name__ == "__main__":
    # Run main program as a single function.
    main(None)
