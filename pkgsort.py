# Import Python packages.
import argparse
import json
import math
from typing import Dict, List, Optional, Sequence, Set, Tuple


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

    # Load JSON file.
    with open(args.path, "r") as file:
        # Load raw dependency tree.
        dependencies = json.load(file)
    require: Dict[str, Set[str]]
    require = {}
    respond: Dict[str, Set[str]]
    respond = {}
    focus = "package_name"
    while len(dependencies) > 0:
        # Take a package away from cache and parse its info.
        info = dependencies.pop(0)
        dependencies.extend(info["dependencies"])
        for name in [info[focus]] + [
            subinfo[focus] for subinfo in info["dependencies"]
        ]:
            # We will track dependency tree in both direction separately.
            for link in [require, respond]:
                # Add every currently involved package into tracking tree.
                if name not in link:
                    # Add a package to tracking tree by creating an empty adjacency set for it.
                    link[name] = set([])
        for subinfo in info["dependencies"]:
            # Build link from each dependent package to parsed package.
            require[info[focus]].add(subinfo[focus])
            respond[subinfo[focus]].add(info[focus])

    # Scan for the bottom-level packages.
    bottom = [name for name, neighbors in require.items() if len(neighbors) == 0]

    # Traverse the tree from bottom level following dependency direction.
    queue = [name for name in bottom]
    levels = {name: 0 for name in bottom}
    while len(queue) > 0:
        # Get a package, and update maximum depths of its responsing packages.
        node = queue.pop(0)
        level = levels[node] + 1
        for child in respond[node]:
            # If depth of responsing package is updated (created or increased), we need to update
            # all its responsing packages again.
            if child not in levels or levels[child] < level:
                # Update depth, and add the package to updating queue.
                levels[child] = level
                queue.append(child)

    # Group all packages in order by levels.
    groups: List[List[Tuple[int, str]]]
    groups = []
    for i, (name, level) in enumerate(
        reversed(
            sorted(levels.items(), key=lambda x: (x[1], x[0].lower()), reverse=True)
        )
    ):
        # Level will grow gradually, thus we can gradually expand groups.
        if level == len(groups):
            # We only need to add one level group under gradual growth.
            groups.append([])
            index = 0

        # Quickly and incrementally generate an index without 0 in it.
        index += 1
        increment = int(str(index).replace("0", "1")) - index
        index += increment
        groups[level].append((index, name))

    # Collect maximum index over all groups for unique ID generation with group information.
    base = max(max(index for index, _ in group) for group in groups)
    base = 10 ** len(str(base))
    for i, group in enumerate(groups):
        # We want to separate different groups in overall package index representation.
        for index, name in group:
            # We use zero digit as separator between group ID and package index in group, thus group
            # ID base should always move one digit left.
            print((i + 1) * 10 * base + index, name)


# Main-program-only operations which is not included in library module operations.
if __name__ == "__main__":
    # Run main program as a single function.
    main(None)
