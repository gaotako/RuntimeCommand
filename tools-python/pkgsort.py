# Import Python packages.
import argparse
import json
import re
from typing import Dict, List, Mapping, Optional, Sequence, Tuple, Type, TypeVar, Union


# Self type annotations.
SelfVersion = TypeVar("SelfVersion", bound="Version")
SelfLiteral = TypeVar("SelfLiteral", bound="Literal")


class Version(object):
    r"""
    Version information container.
    """
    # Constants.
    PRES = {"a": 0, "b": 1, "rc": 2, "alpha": 0, "beta": 1, "c": 2, "pre": 2, "preview": 2}
    PRES_ = ["a", "b", "rc"]
    POSTS = {"post": 0, "rev": 0, "r": 0}
    POSTS_ = ["post"]

    def __init__(self: SelfVersion, message: str, /) -> None:
        r"""
        Initialize the class.

        Args
        ----
        - message
            A package version dependency message in `pip` format.

        Returns
        -------
        """
        # Save essential attributes.
        (
            self.epoch,
            self.release,
            self.wildcard,
            self.pre,
            self.post,
            self.dev,
            self.local,
        ) = self.parse_values(message)

    @classmethod
    def parse_values(
        cls: Type[SelfVersion], message: str, /
    ) -> Tuple[
        int,
        Sequence[int],
        int,
        Tuple[int, int],
        Tuple[int, int],
        Tuple[int, int],
        Sequence[Union[str, int]],
    ]:
        r"""
        Parse version values from version message.

        Args
        ----
        - message
            A package version dependency message in `pip` format.

        Returns
        -------
        - epoch
            Parsed version epoch in numeric format.
        - release
            Parsed version release in numeric format.
        - wildcard
            Parsed version release wildcard in numeric format.
        - pre
            Parsed version pre-release in numeric format.
        - post
            Parsed version post-release in numeric format.
        - dev
            Parsed version development release in numeric format.
        - local
            Parsed version local idenfifier in mix format.

        Follow schema defined in Python [Packaging User Guide](https://packaging.python.org/en/latest/specifications/version-specifiers/).
        """
        # Initialize buffers.
        if message.startswith("v"):
            # Preceding "v" should be ignored.
            remain = message[1:]
        else:
            # By default, all input will be used for parsing.
            remain = message

        # Collect epoch segment.
        regex = r"^(?P<value>[0-9]+)!"
        match = re.match(regex, remain)
        if match:
            # Epoch segment is optional, and only proceed if it exists.
            remain = re.sub(regex, "", remain)
            epoch = int(match.group("value"))
        else:
            # Fill by default value.
            epoch = 0

        # Collect essential release segment.
        regex = r"^(?P<value>[0-9]+(\.[0-9]+)*)"
        match = re.match(regex, remain)
        assert match is not None, 'Fail to find release segment from "{:s}".'.format(message)
        remain = re.sub(regex, "", remain)
        release = [int(digits) for digits in match.group("value").split(".")]

        # Collect release wildcard segment.
        regex = r"^(?P<value>\.\*)"
        match = re.match(regex, remain)
        if match:
            # Release wildcard segment is optional, and only proceed if it exists.
            remain = re.sub(regex, "", remain)
            wildcard = 1
        else:
            # Fill by default value.
            wildcard = 0

        # Collect release wildcard segment.
        regex = r"^(?P<value>\.\*)"
        match = re.match(regex, remain)
        if match:
            # Release wildcard segment is optional, and only proceed if it exists.
            remain = re.sub(regex, "", remain)
            wildcard = 1
        else:
            # Fill by default value.
            wildcard = 0

        # Collect pre-release segment.
        regex = r"^[._-]?(?P<cycle>{:s})[._-]?(?P<value>[0-9]+)?".format("|".join(cls.PRES.keys()))
        match = re.match(regex, remain)
        if match:
            # Pre-release segment is optional, and only proceed if it exists.
            remain = re.sub(regex, "", remain)
            pre = (
                cls.PRES[match.group("cycle")],
                0 if match.group("value") is None else int(match.group("value")),
            )
        else:
            # Fill by default value.
            # Pay attention that default cycle is final (implicit).
            pre = (3, 0)

        # Collect post-release segment.
        # Post-release has a special corner case to be explicitly accepted.
        regex = r"^([._-]?(?P<cycle>{:s})[._-]?(?P<value1>[0-9]+)?|-(?P<value2>[0-9]+))".format(
            "|".join(cls.POSTS.keys())
        )
        match = re.match(regex, remain)
        if match:
            # Post-release segment is optional, and only proceed if it exists.
            remain = re.sub(regex, "", remain)
            if match.group("cycle") is None:
                # Special corner case: bar symbol with value.
                post = (0, int(match.group("value2")))
            else:
                # Otherwise, cycle must be provided with optional value.
                post = (
                    cls.POSTS[match.group("cycle")],
                    0 if match.group("value1") is None else int(match.group("value1")),
                )
        else:
            # Fill by default value.
            # Pay attention that default cycle is final (implicit).
            post = (1, 0)

        # Collect development release segment.
        regex = r"^[._-]?dev[._-]?(?P<value>[0-9]+)?"
        match = re.match(regex, remain)
        if match:
            # Pre-release segment is optional, and only proceed if it exists.
            remain = re.sub(regex, "", remain)
            dev = (0, 0 if match.group("value") is None else int(match.group("value")))
        else:
            # Fill by default value.
            # Pay attention that default cycle is final (implicit).
            dev = (1, 0)

        # Collect local identifier segment.
        regex = r"^\+(?P<value>[a-zA-Z0-9]+(\.[a-zA-Z0-9]+)*)"
        match = re.match(regex, remain)
        if match:
            # Local identifier segment is optional, and only proceed if it exists.
            remain = re.sub(regex, "", remain)
            local = [
                int(segment) if segment.isdigit() else segment
                for segment in match.group("value").split(".")
            ]
        else:
            # Fill by default value.
            local = []

        # Version message should be perfectly parsed with no residuals.
        assert not remain, 'Fail to properly parse version "{:s}".'.format(message)
        return (epoch, release, wildcard, pre, post, dev, local)

    def __repr__(self: SelfVersion, /) -> str:
        r"""
        Represent the class as a string.

        Args
        ----

        Returns
        -------
        - repr
            Representation of the class.
        """
        # Return both version text and number-only version text.
        buf = []
        if self.epoch > 0:
            # Optional epoch segment exists.
            buf.append("{:d}!".format(self.epoch))
        buf.append(".".join(str(digits) for digits in self.release))
        if self.wildcard > 0:
            # Optional release wildcard segment exists.
            buf.append(".*")
        if self.pre < (3, 0):
            # Optional pre-release segment exists.
            cycle, digits = self.pre
            buf.append("{:s}{:d}".format(self.PRES_[cycle], digits))
        if self.post < (1, 0):
            # Optional post-release segment exists.
            cycle, digits = self.post
            buf.append(".{:s}{:d}".format(self.POSTS_[cycle], digits))
        if self.dev < (1, 0):
            # Optional development release segment exists.
            _, digits = self.dev
            buf.append(".dev{:d}".format(digits))
        if self.local:
            # Optional development release segment exists.
            buf.append("+{:s}".format(".".join(str(segment) for segment in self.local)))
        return "".join(buf)


class Literal(object):
    r"""
    Version literal container.
    """
    # Comparators.
    COMPARATORS_ID_TO_MSG = ["~=", "==", "!=", "<=", ">=", "<", ">"]
    AE, EQ, NE, LE, GE, LT, GT = range(len(COMPARATORS_ID_TO_MSG))

    def __init__(self: SelfLiteral, message: str, /) -> None:
        r"""
        Initialize the class.

        Args
        ----
        - message
            A package version rule message in `pip` format.

        Returns
        -------
        """
        # Save essential attributes.
        self.comparator, self.version = self.parse_literal(message)

    @classmethod
    def parse_literal(cls: Type[SelfLiteral], message: str, /) -> Tuple[int, Version]:
        r"""
        Parse version literal from version message.

        Args
        ----
        - message
            A package version dependency message in `pip` format.

        Returns
        -------
        - comparator
            Comparator ID.
        - version
            Version container.
        """
        # Matching prefix literal message with one of comparator text.
        for comparator, prefix in enumerate(cls.COMPARATORS_ID_TO_MSG):
            # Try to match each comparator text with literal message prefix.
            if message.startswith(prefix):
                # If a perfect matching is found, translate it into comparater ID and version value.
                return comparator, Version(message[len(prefix) :])
        raise RuntimeError('"{:s}" can not be recognized as version literal.'.format(message))

    def __repr__(self: SelfLiteral, /) -> str:
        r"""
        Represent the class as a string.

        Args
        ----

        Returns
        -------
        - repr
            Representation of the class.
        """
        # Compose comparater text with version value.
        return "{:s}{:s}".format(self.COMPARATORS_ID_TO_MSG[self.comparator], repr(self.version))


def parse_dependency_edge(src: str, dst: str, message: str, /) -> Sequence[Literal]:
    r"""
    Formalize a dependency edge message.

    Args
    ----
    - src
        Source package name.
    - dst
        Destination package name whose version restriction is being parsed.
    - message
        Version restriction message.

    Returns
    -------
    - cnf
        A conjunctive normal form of version literals.
    """
    # Version dependency can be described as conjunction normal form.
    if message == "Any":
        # Any is a special case for no dependency.
        return []
    else:
        # Otherwise, dependency is a list of version literals to be conjuncted.
        return [Literal(literal) for literal in message.split(",")]


def parse_dependency_tree(
    path: str,
    /,
    *,
    node: str = "package_name",
    neighbors: str = "dependencies",
    attribute: str = "required_version",
    extra: str = "installed_version",
) -> Tuple[
    Mapping[str, Version],
    Mapping[str, Mapping[str, Sequence[Literal]]],
    Mapping[str, Mapping[str, Sequence[Literal]]],
]:
    r"""
    Parse dependency tree into bidirectional version graph.

    Args
    ----
    - path
        Path to `pipdeptree` JSON output.

    Returns
    -------
    - installed
        Installed version of each package.
    - require
        Version conjunctive normal form of destination in direction from source to destination
        (requirement from source).
    - respond
        Version conjunctive normal form of destination in direction from destination to source
        (respond from destination).
    """
    # Load JSON file.
    with open(path, "r") as file:
        # Load raw dependency tree into cache.
        cache = json.load(file)

    # Initialize graph.
    installed: Dict[str, Version]
    installed = {}
    require: Dict[str, Dict[str, List[Literal]]]
    require = {}
    respond: Dict[str, Dict[str, List[Literal]]]
    respond = {}

    # Trasverse hierarchy dependency tree information by BFS.
    while len(cache) > 0:
        # Take a package away from cache and add its neighbors into cache to continue traversing.
        info = cache.pop(0)
        cache.extend(info[neighbors])

        # Parse information of currently taking package.
        source = str(info[node])
        installed[source] = Version(str(info[extra]))

        # Parse neighbor information of currently taking packages to construct dependency edges.
        destinations = [str(subinfo[node]) for subinfo in info[neighbors]]
        attributes = [
            parse_dependency_edge(source, str(subinfo[node]), str(subinfo[attribute]))
            for subinfo in info[neighbors]
        ]

        # Create buffer in bidirectional graph for any new nodes that are not registered.
        for direction in [require, respond]:
            # Allocate essential buffer for all involved nodes.
            for name in [source, *destinations]:
                # Check if buffer of an involved node (package) has been allocated.
                if name not in direction:
                    # Allocate buffer for newly involved node.
                    direction[name] = {}

        # Put dependency information to related nodes.
        for destination, cnf in zip(destinations, attributes):
            # The graph is a multigraph, thus an edge between source and destination may have
            # multiple attributes.
            # Since each attribute will be a conjunctive normal form, and multiple dependencies
            # should be conjuncted, we can summarize multiple conjunctive normal forms as a single
            # conjunctive normal form.
            if destination not in require[source]:
                # Create an empty conjunctive normal form to hold dependency information on
                # destination in direction from source to destination.
                require[source][destination] = []
            if source not in respond[destination]:
                # Create an empty conjunctive normal form to hold dependency information on
                # destination in direction from destination to source.
                respond[destination][source] = []
            require[source][destination].extend(cnf)
            respond[destination][source].extend(cnf)
    return installed, require, respond


def main(terms: Optional[Sequence[str]], /) -> None:
    r"""
    Main program.

    Args
    ----
    - terms
        Terminal keywords.

    Returns
    -------
    """
    # YAML configuration is an essential argument for all applications.
    parser = argparse.ArgumentParser(description="Package Sorting by Depenedency.")
    parser.add_argument("dependency", type=str, help="Dependency tree JSON file.")
    parser.add_argument("requirement", type=str, help="Sorted package version range text file.")
    parser.add_argument(
        "installation", type=str, help="Sorted package installed version text file."
    )
    parser.add_argument("--inspect", nargs="*", default=[], help="Inspecting packages.")
    args = parser.parse_args(terms)

    # Decode arguments.
    dependency = str(args.dependency)
    #:||requirement = str(args.requirement)
    #:||installation = str(args.installation)
    inspect = [str(name) for name in args.inspect]

    # Get version graph from dependency tree.
    _, _, respond = parse_dependency_tree(dependency)
    for destination in inspect:
        # Traverse all responsing packages.
        for source, cnf in respond[destination].items():
            # Report version requirements and their source.
            print(
                "{:s} (from {:s}): {:s}".format(
                    destination,
                    source,
                    "Any" if not cnf else ",".join(repr(literal) for literal in cnf),
                )
            )


# Run main program in non-import mode.
if __name__ == "__main__":
    # Run main program.
    main(None)


# # Import Python packages.
# import argparse
# import json
# import logging
# import re
# import string
# from typing import Dict, List, Mapping, Optional, Sequence, Tuple

# # Import external packages.
# import more_itertools as xitertools


# # Default version number constants.
# VERMIN = 0
# VERMAX = 2**63 - 2


# def parse_version_message(
#     package: str, message: str, /
# ) -> Sequence[Tuple[Tuple[str, Sequence[int]], str]]:
#     r"""
#     Formalize version message into joinable format.

#     Args
#     ----
#     - package
#         Package whose version message is being parsed.
#     - message
#         A package version dependency message in `pip` format.

#     Returns
#     -------
#     - rules
#         Version rules to be joined (AND based).
#     """
#     # Version message contains multiple version restrictions concatenated by comma.
#     rules: List[Tuple[Tuple[str, Sequence[int]], str]]
#     rules = []
#     for restrict in message.split(","):
#         # Each restriction is consisted by a comparator and version numbers.
#         i = 0
#         for i in range(len(restrict)):
#             # Scan heading characters for the comparator.
#             if restrict[i] not in string.punctuation:
#                 # Stop on first non-comparator character.
#                 break
#         prefix = restrict[:i]
#         suffix = restrict[i:]

#         # The first part is the comparator.
#         # If there is not hit, the comparator (first part) will be empty.
#         comparator = prefix

#         # The remaining part is the version numbers concatenated by punctuations.
#         # Since the restriction can have no version numbers, we store a version numbe sequence in
#         # another sequence.
#         buf: Sequence[Sequence[int]]
#         try:
#             # Try to get version numbers of preserved keywords.
#             buf = {"Any": []}[suffix]
#         except KeyError:
#             # Otherwise, get version numbers following common PEP rule.
#             # Some version number may contain characters that is not comparable, and we will warn
#             # and ignore them.
#             if not re.fullmatch(r"[0-9]+(.[0-9]+)*", suffix):
#                 # Warn irregular message format.
#                 logging.warning(
#                     'Irregular version number string "{:s}" from package "{:s}".'.format(
#                         suffix, package
#                     )
#                 )
#             buf = [[int(part) for part in re.split(r"[^0-9]+", suffix) if part]]

#         # We need to save original restriction message since this formalization is not always
#         # revertible.
#         rules.extend(((comparator, numbers), restrict) for numbers in buf)
#     return rules


# def parse_dependency_tree(
#     path: str, /
# ) -> Tuple[
#     Mapping[str, Mapping[str, Sequence[Tuple[Tuple[str, Sequence[int]], str]]]],
#     Mapping[str, Mapping[str, Sequence[Tuple[Tuple[str, Sequence[int]], str]]]],
#     Mapping[str, str],
# ]:
#     r"""
#     Parse dependency tree into bidirectional version graph.

#     Args
#     ----
#     - path
#         Path to `pipdeptree` JSON output.

#     Returns
#     -------
#     - require
#         The version rules (AND based) of each package requiring to other packages.
#     - respond
#         The version rules (AND based) of each package responsing to other package requirements.
#     - installed
#         Install versions.
#     """
#     # Load JSON file.
#     with open(path, "r") as file:
#         # Load raw dependency tree.
#         dependencies = json.load(file)

#     # Graph construction related information domains.
#     node = "package_name"
#     neighbors = "dependencies"
#     attribute = "required_version"
#     extra = "installed_version"

#     # Initialize graph.
#     require: Dict[str, Dict[str, List[Tuple[Tuple[str, Sequence[int]], str]]]]
#     require = {}
#     respond: Dict[str, Dict[str, List[Tuple[Tuple[str, Sequence[int]], str]]]]
#     respond = {}
#     installation: Dict[str, str]
#     installation = {}

#     # Trasverse hierarchy dependency tree information.
#     while len(dependencies) > 0:
#         # Take a package away from cache and add its neighbors into cache to continue traversing.
#         info = dependencies.pop(0)
#         dependencies.extend(info[neighbors])

#         # Parse focusing package info into graph edges
#         source = info[node]
#         destinations = [subinfo[node] for subinfo in info[neighbors]]
#         attributes = [
#             parse_version_message(subinfo[node], subinfo[attribute]) for subinfo in info[neighbors]
#         ]
#         installation[source] = info[extra]

#         # Create buffer in bidirectional graph for any new nodes that are not registered.
#         for direction in [require, respond]:
#             # Traverse all involved nodes to find new nodes.
#             for name in [source, *destinations]:
#                 # Check if the node (package) name has been registered in focusing graph direction.
#                 if name not in direction:
#                     # Register cache for new node in focusing graph direction.
#                     direction[name] = {}

#         # Traverse all neighbors.
#         for destination, rules in zip(destinations, attributes):
#             # The graph is a multigraph, thus an edge between source and destination will have
#             # multiple attributes.
#             if destination not in require[source]:
#                 # Create an empty buffer to hold multiple attributes from source to destination.
#                 require[source][destination] = []
#             if source not in respond[destination]:
#                 # Create an empty buffer to hold multiple attributes from destination to source.
#                 respond[destination][source] = []
#             require[source][destination].extend(rules)
#             respond[destination][source].extend(rules)
#     return require, respond, installation


# def vergt(
#     test: Sequence[int], criterion: Sequence[int], /, *, vermin: int = VERMIN, vermax: int = VERMAX
# ) -> bool:
#     r"""
#     Test if testing version numbers are greater than criterion.

#     Args
#     ----
#     - test
#         Testing version numbers.
#     - criterion
#         Criterion version numbers.
#     - vermin
#         Minimum appeared version number.
#     - vermax
#         Maximum appeared version number.

#     Returns
#     -------
#     - flag
#         If True, testing version numbers are greater than criterion.
#     """
#     # Test with left alignment.
#     test = list(test) + [vermin] * max(len(criterion) - len(test), 0)
#     criterion = list(criterion) + [vermin] * max(len(test) - len(criterion), 0)
#     for num_test, num_criterion in zip(test, criterion):
#         # Compare each pair of aligned numbers.
#         if num_test > num_criterion:
#             # If aligned testing number is larger, testing version numbers are larger.
#             return True
#         elif num_test < num_criterion:
#             # If aligned testing number is less, testing version numbers are less.
#             return False
#     return False


# def verlt(
#     test: Sequence[int], criterion: Sequence[int], /, *, vermin: int = VERMIN, vermax: int = VERMAX
# ) -> bool:
#     r"""
#     Test if testing version numbers are less than criterion.

#     Args
#     ----
#     - test
#         Testing version numbers.
#     - criterion
#         Criterion version numbers.
#     - vermin
#         Minimum appeared version number.
#     - vermax
#         Maximum appeared version number.

#     Returns
#     -------
#     - flag
#         If True, testing version numbers are less than criterion.
#     """
#     # Test with left alignment.
#     test = list(test) + [vermin] * max(len(criterion) - len(test), 0)
#     criterion = list(criterion) + [vermin] * max(len(test) - len(criterion), 0)
#     for num_test, num_criterion in zip(test, criterion):
#         # Compare each pair of aligned numbers.
#         if num_test < num_criterion:
#             # If aligned testing number is less, testing version numbers are less.
#             return True
#         elif num_test > num_criterion:
#             # If aligned testing number is larger, testing version numbers are larger.
#             return False
#     return False


# def simplify_restrict(
#     package: str,
#     restrict: Tuple[Tuple[str, Sequence[int]], str],
#     /,
#     *,
#     vermin: int = VERMIN,
#     vermax: int = VERMAX,
# ) -> Sequence[Sequence[Tuple[Tuple[str, Sequence[int]], str]]]:
#     r"""
#     Simplify restriction so that only GE and LE comparators are used.

#     Args
#     ----
#     - package
#         Package whose restrictions are being joined.
#     - restrict
#         A restriction with any comparator.
#     - vermin
#         Minimum appeared version number.
#     - vermax
#         Maximum appeared version number.

#     Returns
#     -------
#     - restricts
#         Two-level simplfied restrictions with only GE and LE comparators.
#         The first level is AND based, while the second level is OR based.
#     """
#     # Parse restriction.
#     (comparator, numbers), message = restrict

#     # Not-equal operator will result in OR based transformation:
#     if comparator == "!=":
#         # Level 2: Either GE closely higher version or closely lower version.
#         return [
#             [
#                 ((">=", [*numbers, vermin + 1]), message.replace("!=", ">")),
#                 (("<=", [*numbers, vermin - 1]), message.replace("!=", "<")),
#             ]
#         ]

#     # Equal operator will result in AND based transformation:
#     if comparator == "==":
#         # Level 1: Both GE current version and LE current version.
#         return [[((">=", numbers), message)], [(("<=", numbers), message)]]

#     # Roughly-equal operator will result in AND based transformation:
#     if comparator == "~=":
#         # Level 1: Both GE current version and LE current version maximum.
#         # Since we do not know current version maximum, we do the trick by LE closely lower version
#         # of next major version.
#         return [
#             [((">=", numbers), message)],
#             [(("<=", [*numbers[:-2], numbers[-2] + 1, vermin - 1]), message)],
#         ]

#     # GT operator will result in direct transformation:
#     if comparator == ">":
#         # Level 1: GE closely higher version.
#         return [[((">=", [*numbers, vermin + 1]), message)]]

#     # LT operator will result in direct transformation:
#     if comparator == "<":
#         # Level 1: LE closely lower version.
#         return [[(("<=", [*numbers, vermin - 1]), message)]]

#     # GE operator will result in direct transformation:
#     if comparator == ">=":
#         # Level 1: GE current version.
#         return [[((">=", numbers), message)]]

#     # LE operator will result in direct transformation:
#     if comparator == "<=":
#         # Level 1: LE current version.
#         return [[(("<=", numbers), message)]]

#     # All valid comparator should have been captured above.
#     logging.error('Unknown comparator "{:s}".'.format(comparator))
#     raise RuntimeError("See error log")


# def init_ranges_annotated(
#     package: str,
#     restrict: Sequence[Tuple[Tuple[str, Sequence[int]], str]],
#     /,
#     *,
#     vermin: int = VERMIN,
#     vermax: int = VERMAX,
# ) -> Sequence[Tuple[Tuple[Sequence[int], str], Tuple[Sequence[int], str]]]:
#     r"""
#     Initialize joining version number range bounds.

#     Args
#     ----
#     - package
#         Package whose restrictions are being joined.
#     - restrict
#         A restriction used to initial the ranges.
#     - vermin
#         Minimum appeared version number.
#     - vermax
#         Maximum appeared version number.

#     Returns
#     -------
#     - ranges
#         Initialized version range bounds.
#     """
#     # Generate bound for each bottom level rule.
#     ranges: List[Tuple[Tuple[Sequence[int], str], Tuple[Sequence[int], str]]]
#     ranges = []
#     for (comparator, numbers), message in restrict:
#         # Generate bound based on GE or LE comparator.
#         if comparator == ">=":
#             # GE generates a range with lower bound.
#             ranges.append(((numbers, message), ([vermax + 1], "")))
#         else:
#             # LE generates a range with upper bound.
#             ranges.append((([vermin - 1], ""), (numbers, message)))
#     return ranges


# def update_ranges_annotated(
#     package: str,
#     outdated: Sequence[Tuple[Tuple[Sequence[int], str], Tuple[Sequence[int], str]]],
#     restrict: Sequence[Tuple[Tuple[str, Sequence[int]], str]],
#     /,
#     *,
#     vermin: int,  # =VERMIN,
#     vermax: int,  # =VERMAX,
# ) -> Sequence[Tuple[Tuple[Sequence[int], str], Tuple[Sequence[int], str]]]:
#     r"""
#     Update joining version number range bounds.

#     Args
#     ----
#     - package
#         Package whose restrictions are being joined.
#     - outdated
#         Old range bounds.
#     - restrict
#         A restriction used to initial the ranges.
#     - vermin
#         Minimum appeared version number.
#     - vermax
#         Maximum appeared version number.

#     Returns
#     -------
#     - updated
#         Updated version range bounds.
#     """
#     # Each bottom rule may generate a pair of new range bounds.
#     buf = []
#     for (comparator, compare_numbers), compare_message in restrict:
#         # Joining each bottom rule will comparing rule may geneate a pair of new range bounds.
#         for (lower_numbers, lower_message), (upper_numbers, upper_message) in outdated:
#             # Generate bound based on GE or LE comparator.
#             if comparator == ">=":
#                 # GE generates a range with updated lower bound.
#                 if vergt(compare_numbers, upper_numbers, vermin=vermin, vermax=vermax):
#                     # If comparing version number is greater than upper bound, then no bound can be
#                     # generated.
#                     continue
#                 elif vergt(compare_numbers, lower_numbers, vermin=vermin, vermax=vermax):
#                     # If comparing version number is greater than lower bound, then replace lower
#                     # bound by comparing version number.
#                     (
#                         (update_lower_numbers, update_lower_message),
#                         (update_upper_numbers, update_upper_message),
#                     ) = (compare_numbers, compare_message), (upper_numbers, upper_message)
#                 else:
#                     # Otherwise, keep original bounds.
#                     (
#                         (update_lower_numbers, update_lower_message),
#                         (update_upper_numbers, update_upper_message),
#                     ) = (lower_numbers, lower_message), (upper_numbers, upper_message)
#             else:
#                 # LE generates a range with updated upper bound.
#                 if verlt(compare_numbers, lower_numbers, vermin=vermin, vermax=vermax):
#                     # If comparing version number is less than lower bound, then no bound can be
#                     # generated.
#                     continue
#                 elif verlt(compare_numbers, upper_numbers, vermin=vermin, vermax=vermax):
#                     # If comparing version number is less than upper bound, then replace upper bound
#                     # by comparing version number.
#                     (
#                         (update_lower_numbers, update_lower_message),
#                         (update_upper_numbers, update_upper_message),
#                     ) = (lower_numbers, lower_message), (compare_numbers, compare_message)
#                 else:
#                     # Otherwise, keep original bounds.
#                     (
#                         (update_lower_numbers, update_lower_message),
#                         (update_upper_numbers, update_upper_message),
#                     ) = (lower_numbers, lower_message), (upper_numbers, upper_message)

#             # Filter invalid bounhds before update.
#             if verlt(update_upper_numbers, update_lower_numbers, vermin=vermin, vermax=vermax):
#                 # Upper bound being less than lower bound is invalid.
#                 continue
#             buf.append(
#                 (
#                     (update_lower_numbers, update_lower_message),
#                     (update_upper_numbers, update_upper_message),
#                 )
#             )
#     return buf


# def first_diff(test: Sequence[int], criterion: Sequence[int], /) -> int:
#     r"""
#     Get location of first difference between testing version numbers and criterion.

#     Args
#     ----
#     - test
#         Testing version numbers.
#     - criterion
#         Criterion version numbers.

#     Returns
#     -------
#     - loc
#         Location of first difference.
#     """
#     # Test with left alignment.
#     for i, (num_test, num_criterion) in enumerate(zip(test, criterion)):
#         # Return on the first hit.
#         if num_test != num_criterion:
#             # Return hitting location.
#             return i
#     return min(len(test), len(criterion))


# def join_restricts(
#     package: str,
#     restricts: Sequence[Tuple[Tuple[str, Sequence[int]], str]],
#     /,
#     *,
#     vermin: int = VERMIN,
#     vermax: int = VERMAX,
# ) -> str:
#     r"""
#     Join a sequence of restrictions into final range bounds.

#     Args
#     ----
#     - package
#         Package whose restrictions are being joined.
#     - restricts
#         A sequence of restrictions.
#     - vermin
#         Minimum appeared version number.
#     - vermax
#         Maximum appeared version number.

#     Returns
#     -------
#     - message
#         Latest minimum and maximum requirement message.
#     """
#     # Simply all restricts for ease of joining.
#     simplified_restricts = list(
#         xitertools.flatten(
#             simplify_restrict(package, restrict, vermin=vermin, vermax=vermax)
#             for restrict in restricts
#         )
#     )
#     if not simplified_restricts:
#         # If there is no restrictions, return empty string.
#         return ""

#     # Initialize the iteratively updating bound buffer by the first restriction, then iterative join
#     # each restrict into final ranges.
#     ranges = init_ranges_annotated(package, simplified_restricts[0], vermin=vermin, vermax=vermax)
#     for simplified_restrict in simplified_restricts[1:]:
#         # Update final ranges with debug.
#         ranges = update_ranges_annotated(
#             package, ranges, simplified_restrict, vermin=vermin, vermax=vermax
#         )

#     #:||# We sort by boundery difference to maximize the likelihood to find a version hit.
#     #:||losses = [
#     #:||    (loc, loss)
#     #:||    for loss, loc in sorted(
#     #:||        [
#     #:||            (first_diff(upper_numbers, lower_numbers), loc)
#     #:||            for loc, ((lower_numbers, _), (upper_numbers, _)) in enumerate(ranges)
#     #:||        ]
#     #:||    )
#     #:||]
#     #:||ranges = [ranges[loc] for loc, loss in losses if loss == losses[0][1]]
#     #:||# If we still have multiple choices, we pick the one with smaller lower bound for best
#     #:||# stability.
#     #:||(final_lower_numbers, final_lower_message), (_, final_upper_message) = ranges[0]
#     #:||for (lower_numbers, lower_message), (_, upper_message) in ranges[1:]:
#     #:||    if verlt(lower_numbers, final_lower_numbers, vermin=vermin, vermax=vermax):
#     #:||        # Update final boundaries by older versions.
#     #:||        final_lower_numbers = lower_numbers
#     #:||        final_lower_message = lower_message
#     #:||        final_upper_message = upper_message
#     #:||# Collect information except initialization paddings.
#     #:||if final_lower_message == final_upper_message:
#     #:||    # In some cases, final messages will be the same.
#     #:||    final_messages = [final_lower_message]
#     #:||else:
#     #:||    # Otherwise, we need to provide both lower and upper bound messages.
#     #:||    final_messages = [final_lower_message, final_upper_message]

#     # We sort in ascending order.
#     order = list(
#         sorted(range(len(ranges)), key=lambda i: (tuple(ranges[i][0][0]), tuple(ranges[i][1][0])))
#     )
#     ranges = [ranges[i] for i in order]
#     #:||ranges = list(xitertools.flatten([ranges[i] for i in order]))

#     # Get final boundaries.
#     for thing in ranges:
#         print(thing)
#     exit()
#     return ",".join(message for message in final_messages if len(message) > 0)


# def get_depths_from_leaves(
#     require: Mapping[str, Mapping[str, Sequence[Tuple[Tuple[str, Sequence[int]], str]]]],
#     respond: Mapping[str, Mapping[str, Sequence[Tuple[Tuple[str, Sequence[int]], str]]]],
#     /,
# ) -> Mapping[str, int]:
#     r"""
#     Get node depth from leaves.

#     Args
#     ----
#     - require
#         The version rules (AND based) of each package requiring to other packages.
#     - respond
#         The version rules (AND based) of each package responsing to other package requirements.

#     Returns
#     -------
#     - depths
#         Node depths from bottom leaves.
#     """
#     # Starting from packages that have no requirement to other packages.
#     buf = [source for source, neighbors in require.items() if not neighbors]

#     # Iteratively traverse all nodes from starting packages.
#     depths = {source: 0 for source in require}
#     while len(buf) > 0:
#         # Take a package away from cache.
#         source = buf.pop(0)

#         # Traverse all its neighbors, and add updated ones into cache.
#         for destination in respond[source]:
#             # Get new depth according to souce.
#             depth = depths[source] + 1
#             if destination not in buf and depth > depths[destination]:
#                 # If destination depth is updated, put it into cache to continue update.
#                 depths[destination] = depth
#                 buf.append(destination)
#     return depths


# def main(terms: Optional[Sequence[str]], /) -> None:
#     r"""
#     Executable application.

#     Args
#     ----
#     - terms
#         Terminal keywords.

#     Returns
#     -------
#     """
#     # YAML configuration is an essential argument for all applications.
#     parser = argparse.ArgumentParser(description="Package Sorting by Depenedency.")
#     parser.add_argument("dependency", type=str, help="Dependency tree JSON file.")
#     parser.add_argument("requirement", type=str, help="Sorted package version range text file.")
#     parser.add_argument(
#         "installation", type=str, help="Sorted package installed version text file."
#     )
#     parser.add_argument("--inspect", nargs="*", default=[], help="Inspecting packages.")
#     args = parser.parse_args(terms)

#     # Get version graph from dependency tree.
#     require, respond, installation = parse_dependency_tree(args.dependency)
#     for destination in args.inspect:
#         # Traverse all responsing packages.
#         for source, dependencies in respond[destination].items():
#             # Report version requirements and their source.
#             print(
#                 "{:s} {:s} (from {:s})".format(
#                     destination,
#                     "Any" if not dependencies else ",".join(message for _, message in dependencies),
#                     source,
#                 )
#             )

#     # Get minimum and maximum appeared version number.
#     vernums = list(
#         xitertools.collapse(
#             ((numbers for (_, numbers), _ in rules) for rules in neighbors.values())
#             for neighbors in respond.values()
#         )
#     )
#     vermin, vermax = min(vernums), max(vernums)
#     assert vermin >= VERMIN, "Version number minimum assumption is violated."
#     assert vermax <= VERMAX, "Version number maximum assumption is violated."

#     # Get boundaries for each package by joining all rules to the same destination.
#     messages = {}
#     for destination, neighbors in respond.items():
#         # Collect joined version requirement message for each package.
#         messages[destination] = join_restricts(
#             destination, list(xitertools.flatten(neighbors.values())), vermin=VERMIN, vermax=VERMAX
#         )

#     # Report boundaries in ascending depth order from bottom leaves.
#     depths = get_depths_from_leaves(require, respond)
#     groups: Sequence[List[str]]
#     groups = [[] for _ in range(max(depths.values()) + 1)]
#     for name, depth in depths.items():
#         # Add package name to corresponding dependency depth group.
#         groups[depth].append(name)

#     # Generate final report.
#     with open(args.requirement, "w") as file:
#         # Traverse depth groups in reversed order.
#         # This ensures installing as latest version as possible.
#         for group in reversed(groups):
#             # Traverse each depth group in alphabet order.
#             for name in group:
#                 # Output in `pip` format.
#                 file.write("{:s} {:s}".format(name, messages[name]).strip() + "\n")
#     with open(args.installation, "w") as file:
#         # Traverse depth groups in reversed order.
#         # This ensures installing as latest version as possible.
#         for group in reversed(groups):
#             # Traverse each depth group in alphabet order.
#             for name in group:
#                 # Output in `pip` format.
#                 file.write("{:s} {:s}".format(name, installation[name]) + "\n")


# # Main-program-only operations which is not included in library module operations.
# if __name__ == "__main__":
#     # Run main program as a single function.
#     main(None)
