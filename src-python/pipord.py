# Import Python packages.
import argparse
import json
import os
import re
from typing import Dict, List, Mapping, Optional, Sequence, Tuple, Type, TypeVar, Union

# Import external packages.
import more_itertools as xitertools


# Self type annotations.
SelfVersion = TypeVar("SelfVersion", bound="Version")
SelfLiteral = TypeVar("SelfLiteral", bound="Literal")
SelfRange = TypeVar("SelfRange", bound="Range")
SelfRangeDNF = TypeVar("SelfRangeDNF", bound="RangeDNF")


class Version(object):
    r"""
    Version information container.
    """
    # Constants.
    PRES = {"a": 0, "b": 1, "rc": 2, "alpha": 0, "beta": 1, "c": 2, "pre": 2, "preview": 2}
    PRES_ = ["a", "b", "rc"]
    POSTS = {"post": 1, "rev": 1, "r": 1}
    POSTS_ = ["", "post"]

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
        self.message = message

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
        # NOT SURE IF THIS IS CORRECT SINCE SOME INFO IS NOT PROVIDED IN DOC.
        regex = r"^([._-]?(?P<cycle>{:s})[._-]?(?P<value1>[0-9]+)?|-(?P<value2>[0-9]+))".format(
            "|".join(cls.POSTS.keys())
        )
        match = re.match(regex, remain)
        if match:
            # Post-release segment is optional, and only proceed if it exists.
            remain = re.sub(regex, "", remain)
            if match.group("cycle") is None:
                # Special corner case: bar symbol with value.
                post = (1, int(match.group("value2")))
            else:
                # Otherwise, cycle must be provided with optional value.
                post = (
                    cls.POSTS[match.group("cycle")],
                    0 if match.group("value1") is None else int(match.group("value1")),
                )
        else:
            # Fill by default value.
            # Pay attention that default cycle is ahead-of-post (implicit).
            post = (0, 0)

        # Collect development release segment.
        # NOT SURE IF THIS IS CORRECT SINCE SOME INFO IS NOT PROVIDED IN DOC.
        regex = r"^[._-]?dev[._-]?(?P<value>[0-9]+)?"
        match = re.match(regex, remain)
        if match:
            # Pre-release segment is optional, and only proceed if it exists.
            remain = re.sub(regex, "", remain)
            dev = (1, 0 if match.group("value") is None else int(match.group("value")))
        else:
            # Fill by default value.
            # Pay attention that default cycle is ahead-of-dev (implicit).
            dev = (0, 0)

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
        if self.post > (0, 0):
            # Optional post-release segment exists.
            cycle, digits = self.post
            buf.append(".{:s}{:d}".format(self.POSTS_[cycle], digits))
        if self.dev > (0, 0):
            # Optional development release segment exists.
            _, digits = self.dev
            buf.append(".dev{:d}".format(digits))
        if self.local:
            # Optional development release segment exists.
            buf.append("+{:s}".format(".".join(str(segment) for segment in self.local)))
        return "".join(buf)

    @classmethod
    def from_assign(
        cls: Type[SelfVersion],
        /,
        *,
        epoch: int = 0,
        release: Sequence[int] = [],
        wildcard: int = 0,
        pre: Tuple[int, int] = (3, 0),
        post: Tuple[int, int] = (0, 0),
        dev: Tuple[int, int] = (0, 0),
        local: Sequence[Union[int, str]] = [],
        message: Optional[str] = None,
    ) -> SelfVersion:
        r"""
        Create a version by assigning arbitrary values directly.

        Args
        ----
        - epoch
            Epoch.
        - release
            All release segments.
        - wildcard
            Wildcard.
        - pre
            All pre-release segments.
        - pre
            All pre-release segments.
        - post
            All post-release segments.
        - dev
            All development release segments.
        - pre
            All local segments.
        - message
            Raw message corresponding to the assignment.

        Returns
        -------
        - obj
            A version literal.
        """
        # Create a version from assigned values.
        obj = cls("0")
        obj.epoch = epoch
        obj.release = release
        obj.wildcard = wildcard
        obj.pre = pre
        obj.post = post
        obj.dev = dev
        obj.local = local
        obj.message = message if message else repr(obj)
        return obj

    def __lt__(self: SelfVersion, other: SelfVersion, /) -> bool:
        r"""
        Less-than comparator.

        Args
        ----
        - other
            The other object (right operand).

        Returns
        -------
        - flag
            Comparison flag.
        """
        # We zero-pad release numbers to synchronize release length during comparison.
        maxlen = max(len(self.release), len(other.release))
        assert not self.wildcard, "Wildcard is only supported in equality."
        left = (
            self.epoch,
            (*self.release, *([0] * (maxlen - len(self.release)))),
            self.pre,
            self.post,
            self.dev,
        )
        right = (
            other.epoch,
            (*other.release, *([0] * (maxlen - len(other.release)))),
            other.pre,
            other.post,
            other.dev,
        )
        return left < right

    def __gt__(self: SelfVersion, other: SelfVersion, /) -> bool:
        r"""
        Greater-than comparator.

        Args
        ----
        - other
            The other object (right operand).

        Returns
        -------
        - flag
            Comparison flag.
        """
        # We zero-pad release numbers to synchronize release length during comparison.
        maxlen = max(len(self.release), len(other.release))
        assert not self.wildcard, "Wildcard is only supported in equality."
        left = (
            self.epoch,
            (*self.release, *([0] * (maxlen - len(self.release)))),
            self.pre,
            self.post,
            self.dev,
        )
        right = (
            other.epoch,
            (*other.release, *([0] * (maxlen - len(other.release)))),
            other.pre,
            other.post,
            other.dev,
        )
        return left > right

    def to_int(self: SelfVersion, /, *, maxlens: Sequence[int] = []) -> int:
        r"""
        Translate version values into a single integer.

        Args
        ----
        - maxlens
            Maximum number of digits of all possible release segments.

        Returns
        -------
        - value
            An integer value carrying essential version value information.
        """
        # Synchonize number of digits and concatenate all essential value segments.
        return int(
            "".join(
                [
                    "{:>0{:d}d}".format(self.epoch, maxlens[0]),
                    *(
                        "{:>0{:d}d}".format(self.release[i], maxlen)
                        if i < len(self.release)
                        else ("0" * maxlen)
                        for i, maxlen in enumerate(maxlens[1:])
                    ),
                    *(str(segment) for segment in self.pre),
                    *(str(segment) for segment in self.post),
                    *(str(segment) for segment in self.dev),
                ]
            )
        )


class Literal(object):
    r"""
    Version literal container.
    """
    # Comparators.
    COMPARATORS_ID_TO_MSG = ["~=", "==", "!=", "<=", ">=", "<", ">"]
    AE, EQ, NE, LE, GE, LT, GT = range(len(COMPARATORS_ID_TO_MSG))

    # When version value is the same, less-or-equal include larger versions than less-than.
    ORDS_L = {LT: 0, LE: 1}

    # When version value is the same, equality should be treated the same.
    ORDS_E = {AE: 2, EQ: 2, NE: 2}

    # When version value is the same, greater-or-equal include smaller versions than greater-than.
    ORDS_G = {GE: 3, GT: 4}

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
        self.message = message

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

    @classmethod
    def from_assign(
        cls: Type[SelfLiteral],
        comparator: int,
        version: Version,
        /,
        *,
        message: Optional[str] = None,
    ) -> SelfLiteral:
        r"""
        Create a literal by assigning a comparator ID and version value directly.

        Args
        ----
        - comparator
            Comparator ID.
        - version
            Version container.
        - message
            Raw message corresponding to the assignment.

        Returns
        -------
        - obj
            A version literal.
        """
        # Create a literal from comparator ID and version value.
        obj = cls("~=0")
        obj.comparator = comparator
        obj.version = version
        obj.message = message if message else repr(obj)
        return obj

    def __lt__(self: SelfLiteral, other: SelfLiteral, /) -> bool:
        r"""
        Less-than comparator.

        Args
        ----
        - other
            The other object (right operand).

        Returns
        -------
        - flag
            Comparison flag.
        """
        # Version value mainly decides the flag except for some corner cases where comparator
        # matters.
        if self.version < other.version:
            # If version number is smaller, version literal is always considered as smaller.
            return True
        elif self.version > other.version:
            # If version number is larger, version literal is always considered as larger.
            return False
        elif self.comparator in self.ORDS_L and other.comparator in self.ORDS_L:
            # If version number is the same, version literal is compared by comparator.
            return self.ORDS_L[self.comparator] < self.ORDS_L[other.comparator]
        elif self.comparator in self.ORDS_G and other.comparator in self.ORDS_G:
            # If version number is the same, version literal is compared by comparator.
            return self.ORDS_G[self.comparator] < self.ORDS_G[other.comparator]
        else:
            # All the other cases, version literals are not order-comparable.
            raise RuntimeError(
                '"{:s}" is not order-comparable with "{:s}".'.format(repr(self), repr(other))
            )

    def __gt__(self: SelfLiteral, other: SelfLiteral, /) -> bool:
        r"""
        Greater-than comparator.

        Args
        ----
        - other
            The other object (right operand).

        Returns
        -------
        - flag
            Comparison flag.
        """
        # Version value mainly decides the flag except for some corner cases where comparator
        # matters.
        if self.version > other.version:
            # If version number is larger, version literal is always considered as larger.
            return True
        elif self.version < other.version:
            # If version number is smaller, version literal is always considered as smaller.
            return False
        elif self.comparator in self.ORDS_L and other.comparator in self.ORDS_L:
            # If version number is the same, version literal is compared by comparator.
            return self.ORDS_L[self.comparator] > self.ORDS_L[other.comparator]
        elif self.comparator in self.ORDS_G and other.comparator in self.ORDS_G:
            # If version number is the same, version literal is compared by comparator.
            return self.ORDS_G[self.comparator] > self.ORDS_G[other.comparator]
        else:
            # All the other cases, version literals are not order-comparable.
            raise RuntimeError(
                '"{:s}" is not order-comparable with "{:s}".'.format(repr(self), repr(other))
            )

    def to_int(self: SelfLiteral, /, *, maxlens: Sequence[int] = []) -> int:
        r"""
        Translate version literal into a single integer.

        Args
        ----
        - maxlens
            Maximum number of digits of all possible release segments.

        Returns
        -------
        - value
            An integer value carrying essential version literal information.
        """
        # Only arbirary comparator can be translated into integer.
        assert (
            self.comparator in self.ORDS_L or self.comparator in self.ORDS_G
        ), 'Can not translate comparator "{:s}" to integer.'.format(
            self.COMPARATORS_ID_TO_MSG[self.comparator]
        )
        value = self.version.to_int(maxlens=maxlens) * 10
        if self.comparator == self.LE:
            # Less-or-equal should have the largest value.
            value += 9
        elif self.comparator == self.LT:
            # Less-than should have a smaller value.
            value += 8
        elif self.comparator == self.GT:
            # Greater-than should have even smaller value.
            value += 2
        elif self.comparator == self.GE:
            # Greater-or-equal should have the smallest value.
            value += 1
        return value


class Range(object):
    r"""
    Version range container.
    """

    def __init__(self: SelfRange, /) -> None:
        r"""
        Initialize the class.

        Args
        ----

        Returns
        -------
        """
        # Initialize essential attributes.
        self.lower: Optional[Literal]
        self.lower = None
        self.upper: Optional[Literal]
        self.upper = None

    def __repr__(self: SelfRange, /) -> str:
        r"""
        Represent the class as a string.

        Args
        ----

        Returns
        -------
        - repr
            Representation of the class.
        """
        # Put lower and upper bound together as a tuple.
        return "({:s},{:s})".format(repr(self.lower), repr(self.upper))

    @classmethod
    def join(cls: Type[SelfRange], left: SelfRange, right: SelfRange, /) -> SelfRange:
        r"""
        Join two version ranges.

        Args
        ----
        - left
            The left version range operand.
        - right
            The right version range operand.

        Returns
        -------
        - obj
            A joined version range.
        """
        # Create a new version range to hold joining result.
        obj = cls()
        obj.lower = left.lower
        if left.lower is None or (right.lower is not None and left.lower < right.lower):
            # Update lower bound by larger one.
            obj.lower = right.lower
        obj.upper = left.upper
        if left.upper is None or (right.upper is not None and left.upper > right.upper):
            # Update upper bound by smaller one.
            obj.upper = right.upper
        return obj

    def potential(self: SelfRange, /, maxlens: Sequence[int] = []) -> float:
        r"""
        Relative score measuring potential versions between version range.

        Args
        ----
        - maxlens
            Maximum number of digits of all possible release segments.

        Returns
        -------
        - score
            Relative potential version score.
        """
        # Score is esitmated from lower and upper bounds.
        lower = float(self.lower.to_int(maxlens=maxlens)) if self.lower else 0.0
        upper = float(self.upper.to_int(maxlens=maxlens)) if self.upper else float("inf")
        return max(upper - lower, 0.0)


class RangeDNF(object):
    r"""
    Disjunctive normal form of version ranges.
    """

    def __init__(self: SelfRangeDNF, /, *, maxlens: Sequence[int] = []) -> None:
        r"""
        Initialize the class.

        Args
        ----
        - maxlens
            Maximum number of digits of all possible release segments.

        Returns
        -------
        """
        # Initialize essential attributes.
        self.ranges = [Range()]
        self.maxlens = maxlens

    @classmethod
    def from_literal(
        cls: Type[SelfRangeDNF], literal: Literal, /, *, maxlens: Sequence[int] = []
    ) -> SelfRangeDNF:
        r"""
        Create a disjunctive normal form from a version literal.

        Args
        ----
        - literal
            A version literal.
        - maxlens
            Maximum number of digits of all possible release segments.

        Returns
        -------
        - obj
            A disjunctive normal form of version ranges.
        """
        # Fill ranges based on literal comparators.
        obj = cls(maxlens=maxlens)
        obj.ranges.clear()
        comparator = literal.comparator
        if comparator == Literal.AE:
            # Approximate-equal comparator defines both lower and upper bounds.
            # Lower bound is inclusively given version.
            # While upper bound is matching all versions of same epoch and release segments except
            # the tail after lower bound.
            assert not literal.version.wildcard, "Approximate-equal can not compare wildcard."
            default = Range()
            default.lower = Literal.from_assign(
                Literal.GE, literal.version, message=literal.message
            )
            default.upper = Literal.from_assign(
                Literal.LT,
                Version.from_assign(
                    epoch=literal.version.epoch,
                    release=[*literal.version.release[:-2], literal.version.release[-2] + 1],
                    wildcard=0,
                    pre=(0, 0),
                    post=(0, 0),
                    dev=(0, 0),
                    local=[],
                ),
                message=literal.message,
            )
            obj.ranges.append(default)
        elif comparator == Literal.EQ:
            # Equal comparator defines both lower and upper bounds.
            default = Range()
            if literal.version.wildcard:
                # Wildcard will result in a loose bound.
                # Wildcard should inclusively match every version of same epoch and release
                # segments before wildcard.
                # Wildcard should exclusively match every version less than the same epoch and
                # release segments before wildcard with tail increment by 1.
                default.lower = Literal.from_assign(
                    Literal.GE,
                    Version.from_assign(
                        epoch=literal.version.epoch,
                        release=literal.version.release,
                        wildcard=0,
                        pre=(0, 0),
                        post=(0, 0),
                        dev=(0, 0),
                        local=[],
                    ),
                    message=literal.message,
                )
                default.upper = Literal.from_assign(
                    Literal.LT,
                    Version.from_assign(
                        epoch=literal.version.epoch,
                        release=[*literal.version.release[:-1], literal.version.release[-1] + 1],
                        wildcard=0,
                        pre=(0, 0),
                        post=(0, 0),
                        dev=(0, 0),
                        local=[],
                    ),
                    message=literal.message,
                )
            else:
                # Otherwise, regular case will result in a tight bound.
                default.lower = Literal.from_assign(
                    Literal.GE, literal.version, message=literal.message
                )
                default.upper = Literal.from_assign(
                    Literal.LE, literal.version, message=literal.message
                )
            obj.ranges.append(default)
        elif comparator == Literal.NE:
            # Not-equal comparator will result int two disjunctive literals.
            if literal.version.wildcard:
                # Wildcard will exlucde a range of versions matching epoch and release before
                # wildcard.
                default = Range()
                default.upper = Literal.from_assign(
                    Literal.LT,
                    Version.from_assign(
                        epoch=literal.version.epoch,
                        release=literal.version.release,
                        wildcard=0,
                        pre=(0, 0),
                        post=(0, 0),
                        dev=(0, 0),
                        local=[],
                    ),
                    message=literal.message,
                )
                obj.ranges.append(default)
                default = Range()
                default.lower = Literal.from_assign(
                    Literal.GE,
                    Version.from_assign(
                        epoch=literal.version.epoch,
                        release=[*literal.version.release[:-1], literal.version.release[-1] + 1],
                        wildcard=0,
                        pre=(0, 0),
                        post=(0, 0),
                        dev=(0, 0),
                        local=[],
                    ),
                    message=literal.message,
                )
                obj.ranges.append(default)
            else:
                # Otherwise, strictly excludes any version matching epoch and release.
                default = Range()
                default.upper = Literal.from_assign(
                    Literal.LT, literal.version, message=literal.message
                )
                obj.ranges.append(default)
                default = Range()
                default.lower = Literal.from_assign(
                    Literal.GT, literal.version, message=literal.message
                )
                obj.ranges.append(default)
        elif comparator == Literal.LE:
            # Less-or-equal comparator defines an upper bound.
            default = Range()
            default.upper = literal
            obj.ranges.append(default)
        elif comparator == Literal.GE:
            # Greater-or-equal comparator defines a lower bound.
            default = Range()
            default.lower = literal
            obj.ranges.append(default)
        elif comparator == Literal.LT:
            # Less-than comparator defines an upper bound.
            default = Range()
            default.upper = literal
            obj.ranges.append(default)
        elif comparator == Literal.GT:
            # Greater-than comparator defines a lower bound.
            default = Range()
            default.lower = literal
            obj.ranges.append(default)
        assert (
            len(obj.ranges) > 0
        ), 'No version range can be generated from version literal "{:s}".'.format(repr(literal))
        return obj

    def conjunct_(self: SelfRangeDNF, other: SelfRangeDNF, /) -> None:
        r"""
        Conjunct two version range disjunctive normal forms inplace.

        Args
        ----
        - other
            Another version range disjunctive normal form.

        Returns
        -------
        """
        # Try to disjunct every pair of version ranges.
        # Enumerate Left operand from self ranges.
        buf = []
        for left in self.ranges:
            # Enumerate Left operand from other ranges.
            for right in other.ranges:
                # Join two version ranges into a new version range (maybe invalid).
                result = Range.join(left, right)
                if result.potential(maxlens=self.maxlens) > 0.0:
                    # Only range with non-empty potential version score can be valid.
                    buf.append(result)

        # Inplace self ranges by joined ranges.
        self.ranges.clear()
        self.ranges.extend(buf)

        # Update maximum number of digits of all possible release segments.
        self.maxlens = [
            max(maxlen1, maxlen2)
            for maxlen1, maxlen2 in zip(
                (*self.maxlens, *([0] * max(len(other.maxlens) - len(self.maxlens), 0))),
                (*other.maxlens, *([0] * max(len(self.maxlens) - len(other.maxlens), 0))),
            )
        ]

    def __repr__(self: SelfRangeDNF, /) -> str:
        r"""
        Represent the class as a string.

        Args
        ----

        Returns
        -------
        - repr
            Representation of the class.
        """
        # Output every range in separate lines.
        return "[" + "|".join(repr(vrng) for vrng in self.ranges) + "]"


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
    with open(os.path.join(path, "dependencies.json"), "r") as file:
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


def collect_release_maxlens(versions: Sequence[Version], /) -> Sequence[int]:
    r"""
    Collect maximum number of digits of all possible release segments.

    Args
    ----
    - versions
        All version values.

    Returns
    -------
    - maxlens
        Maximum number of digits of all possible release segments including epoch.
    """
    # Traverse release numbers of all versions.
    buf: Sequence[int]
    buf = []
    for version in versions:
        # Get the release, and update maximum length of every release segment.
        segments = [version.epoch, *version.release]
        if len(segments) > len(buf):
            # If we have more segments than buffer, pad the buffer first.
            buf = [*buf, *([0] * (len(segments) - len(buf)))]
        for i, segment in enumerate(segments):
            # Update maximum length of each segment in buffer.
            buf[i] = max(buf[i], len(str(segment)))
    return buf


def conjunct(
    installed: Version, cnf: Sequence[Literal], /, *, maxlens: Sequence[int] = []
) -> Range:
    r"""
    Conjunct version literals into version ranges.

    Args
    ----
    - installed
        Currently installed version.
    - cnf
        Conjunctive normal form of version dependency literals.
    - maxlens
        Maximum number of digits of all possible release segments.

    Returns
    -------
    - recommend
        Best version range recommendation infered from current version and given version literatls.
    """
    # Valid version range should not be earlier than installed version.
    dnf = RangeDNF.from_literal(Literal.from_assign(Literal.GE, installed), maxlens=maxlens)

    # Join all version literals into installed version literal.
    for literal in cnf:
        # Translate version literal into version range, and disjunct with installed version range.
        dnf.conjunct_(RangeDNF.from_literal(literal, maxlens=maxlens))

    # Take range with largest potential from final disjunctive normal form.
    # When potentials are the same, higher lower bound is preferred.
    recommend, *_ = sorted(
        dnf.ranges,
        key=lambda vrng: (
            vrng.potential(maxlens=maxlens),
            vrng.lower.to_int(maxlens=maxlens) if vrng.lower else 0,
        ),
        reverse=True,
    )
    return recommend


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
    parser.add_argument("root", type=str, help="Directory of dependency tree storage.")
    parser.add_argument("--inspect", nargs="*", default=[], help="Inspecting packages.")
    args = parser.parse_args(terms) if terms else parser.parse_args()

    # Decode arguments.
    root = str(args.root)
    inspect = [str(name) for name in args.inspect]

    # Get version graph from dependency tree.
    installed, require, respond = parse_dependency_tree(root)

    # Conjunct version dependencies for each package.
    recommend = {}
    for destination, neighbors in respond.items():
        # Collect all potentially valid version ranges based on dependency information.
        if destination in inspect:
            # Report dependency information of an inspecting package.
            print("{:s} (Installed): >={:s}".format(destination, repr(installed[destination])))
            for source, cnf in respond[destination].items():
                # Report version dependencies and their sources.
                print(
                    "{:s} (from {:s}): {:s}".format(
                        destination,
                        source,
                        "Any" if not cnf else ",".join(repr(literal) for literal in cnf),
                    )
                )
        version = installed[destination]
        literals = list(xitertools.flatten(neighbors.values()))
        recommend[destination] = conjunct(
            version,
            literals,
            maxlens=collect_release_maxlens([version, *(literal.version for literal in literals)]),
        )

    # Collect dependency depth (latest depth in traverse rather than ealiest) of each package.
    depth = {destination: 0 for destination, neighbors in respond.items() if len(neighbors) == 0}
    queue = list(depth.keys())
    while len(queue) > 0:
        # Take a package from queue, and update dependency depths of all its required packages.
        source = queue.pop(0)
        for destination in require[source]:
            # Always update depth to ensure the latest one is collected.
            depth[destination] = depth[source] + 1
            if destination not in queue:
                # Ensure duplication in queue to reduce traverse cost.
                queue.append(destination)

    # Generate reversed package installation order by dependency depth and requirement size to
    # maximize the probability of conflict.
    order = list(
        sorted(
            set(require.keys()) | set(respond.keys()),
            key=lambda name: (depth[name], -len(require[name]), name),
        )
    )

    # Output installed package versions in order
    with open(os.path.join(root, "installations.txt"), "w") as file:
        # Output all detected package versions.
        for name in order:
            # For each row, output package name and its version values.
            line = "{:s} {:s}".format(name, repr(installed[name]))
            file.write(line + "\n")

    # Output package dependency requirements in order.
    with open(os.path.join(root, "requirements.txt"), "w") as file:
        # Output all detected package requirements in `pip` format.
        for name in order:
            # For each row, output package name, and its lower and upper version bound (probably
            # missing).
            vrng = recommend[name]
            specifiers = ", ".join(
                " ".join([Literal.COMPARATORS_ID_TO_MSG[bound.comparator], repr(bound.version)])
                for bound in (vrng.lower, vrng.upper)
                if bound
            )
            line = " ".join(text for text in (name, specifiers) if text)
            file.write(line + "\n")


# Run main program in non-import mode.
if __name__ == "__main__":  # pragma: no cover
    # Run main program.
    main(None)
