# Import Python packages.
import os
import shutil
from typing import Sequence, Tuple

# Import PyTest packages.
import pytest

# Import relatively from other modules.
from utils import rcimport


# imports the module from the given path.
pipord = rcimport("pipord")


# Test cases.
TEST_VERSION_EXCLUSIVE_ORDERED_COMPARISON: Sequence[
    Tuple[bool, str, str, Sequence[pytest.MarkDecorator]]
]
TEST_VERSION_EXCLUSIVE_ORDERED_COMPARISON = [
    (False, "2!1", "1!1", []),
    (False, "2!1", "1!2", []),
    (False, "1!1", "v1", []),
    (False, "1.7.1", "1.7", []),
    (False, "1.7.1", "1.7.0", []),
    (False, "1.7.1", "1.7.0.1", []),
    (False, "1.7", "1.7rc2", []),
    (False, "1.7rc2", "1.7.rc1", []),
    (False, "1.7rc1", "1.7b2", []),
    (False, "1.7b2", "1.7b1", []),
    (False, "1.7b1", "1.7a2", []),
    (False, "1.7a1", "1.6.1", []),
    (False, "1.7.1", "1.7.0.post2", []),
    (False, "1.7.0.post2", "1.7.post1", []),
    (False, "1.7.post1", "1.7", []),
    (False, "1.7.0.post2", "1.7-1", []),
    (False, "1.7-1", "1.7", []),
    (False, "1.7.1", "1.7.0.dev2", []),
    (False, "1.7.0.dev2", "1.7.dev1", []),
    (False, "1.7.dev1", "1.7", []),
    (False, "1.7.dev1", "1.7", []),
    (False, "1.7", "1.7+local2", [pytest.mark.xfail(raises=AssertionError)]),
    (False, "1.7+local2", "1.7+local1", [pytest.mark.xfail(raises=AssertionError)]),
    (False, "1.7", "1.8", [pytest.mark.xfail(raises=AssertionError)]),
]
TEST_LITERAL_EXCLUSIVE_ORDERED_COMPARISON: Sequence[
    Tuple[bool, str, str, Sequence[pytest.MarkDecorator]]
]
TEST_LITERAL_EXCLUSIVE_ORDERED_COMPARISON = [
    (False, ">1.7", ">1.6", []),
    (False, ">1.7", ">=1.7", []),
    (False, "<1.7", "<1.6", []),
    (False, "<=1.7", "<1.7", []),
    (False, "<1.7", ">1.6", []),
    (False, "==1.7", "~=1.6", []),
    (False, "<1.7", ">1.7", [pytest.mark.xfail(raises=RuntimeError)]),
    (True, "<1.7", ">1.7", [pytest.mark.xfail(raises=RuntimeError)]),
    (False, "==1.7", "~=1.7", [pytest.mark.xfail(raises=RuntimeError)]),
    (False, "==1.7", "==1.8", [pytest.mark.xfail(raises=AssertionError)]),
]
TEST_DNF_CONJUNCT = [
    (">1", "<2", "[(>1,<2)]"),
    (">=1", "<=2", "[(>=1,<=2)]"),
    (">1", ">=1", "[(>1,None)]"),
    (">1.6", "==1.7", "[(>=1.7,<=1.7)]"),
    (">1.6", "!=1.7", "[(>1.6,<1.7)|(>1.7,None)]"),
    (">1.6", "==1.7.*", "[(>=1.7a0,<1.8a0)]"),
    (">1.6", "!=1.7.*", "[(>1.6,<1.7a0)|(>=1.8a0,None)]"),
    (">1.6", "~=1.7.1", "[(>=1.7.1,<1.8a0)]"),
    ("<1.7.2", "==1.7", "[(>=1.7,<=1.7)]"),
    ("<1.7.2", "!=1.7", "[(None,<1.7)|(>1.7,<1.7.2)]"),
    ("<1.7.2", "==1.7.*", "[(>=1.7a0,<1.7.2)]"),
    ("<1.7.2", "!=1.7.*", "[(None,<1.7a0)]"),
    ("<1.7.2", "~=1.7.1", "[(>=1.7.1,<1.7.2)]"),
]


@pytest.mark.parametrize(
    ("swap", "version1", "version2"),
    [
        pytest.param(
            swap,
            version1,
            version2,
            marks=marks,
            id=("->" if not marks else "!>").join([version1, version2]),
        )
        for swap, version1, version2, marks in TEST_VERSION_EXCLUSIVE_ORDERED_COMPARISON
    ],
)
def test_version_exclusive_ordered_comparison(*, swap: bool, version1: str, version2: str) -> None:
    r"""
    Test exclusive ordered comparison between version values.

    Args
    ----
    - swap
        If True, swap the execution order of bidirectional compare.
    - version1
        Version 1 which should always be larger in successful cases.
    - version2
        Version 2 which should always be smaller in successful cases.

    Returns
    -------
    """
    # Test version parsing in the meanwhile.
    obj1 = pipord.Version(version1)
    obj2 = pipord.Version(version2)
    assert repr(obj1) == repr(pipord.Version(repr(obj1)))
    assert repr(obj2) == repr(pipord.Version(repr(obj2)))

    # Test ordered comparison of both directions.
    if swap:
        # If swap, check less direction first.
        flag2 = obj2 < obj1
        flag1 = obj1 > obj2
    else:
        # By default, check greater direction first.
        flag1 = obj1 > obj2
        flag2 = obj2 < obj1
    assert flag1 and flag2


@pytest.mark.parametrize(
    ("swap", "literal1", "literal2"),
    [
        pytest.param(
            swap,
            literal1,
            literal2,
            marks=marks,
            id=("=>" if not marks else "!>").join([literal1, literal2]),
        )
        for swap, literal1, literal2, marks in TEST_LITERAL_EXCLUSIVE_ORDERED_COMPARISON
    ],
)
def test_literal_exclusive_ordered_comparison(*, swap: bool, literal1: str, literal2: str) -> None:
    r"""
    Test exclusive ordered comparison between version literals.

    Args
    ----
    - swap
        If True, swap the execution order of bidirectional compare.
    - literal1
        Version literal 1 which should always be larger in successful cases.
    - literal2
        Version literal 2 which should always be smaller in successful cases.

    Returns
    -------
    """
    # Test version literal parsing in the meanwhile.
    obj1 = pipord.Literal(literal1)
    obj2 = pipord.Literal(literal2)
    assert repr(obj1) == repr(pipord.Literal(repr(obj1)))
    assert repr(obj2) == repr(pipord.Literal(repr(obj2)))

    # Test ordered comparison of both directions.
    if swap:
        # If swap, check less direction first.
        flag2 = obj2 < obj1
        flag1 = obj1 > obj2
    else:
        # By default, check greater direction first.
        flag1 = obj1 > obj2
        flag2 = obj2 < obj1
    assert flag1 and flag2


@pytest.mark.parametrize(
    ("dnf1", "dnf2", "result"),
    [
        pytest.param(dnf1, dnf2, result, id="{:s}&{:s}".format(dnf1, dnf2))
        for dnf1, dnf2, result in TEST_DNF_CONJUNCT
    ],
)
def test_dnf_conjunct(*, dnf1: str, dnf2: str, result: str) -> None:
    r"""
    Test conjunction of version range disjunctive normal form.

    Args
    ----
    - dnf1
        Version range disjunctive normal form 1.
    - dnf2
        Version range disjunctive normal form 2.
    - result
        Conjunction output representation.

    Returns
    -------
    """
    # Test version literal parsing in the meanwhile.
    literal1 = pipord.Literal(dnf1)
    literal2 = pipord.Literal(dnf2)
    assert repr(literal1) == repr(pipord.Literal(repr(literal1)))
    assert repr(literal2) == repr(pipord.Literal(repr(literal2)))

    # Computation output should match targert.
    maxlens = pipord.collect_release_maxlens([literal1.version, literal2.version])
    ranges1 = pipord.RangeDNF.from_literal(literal1, maxlens=maxlens)
    ranges2 = pipord.RangeDNF.from_literal(literal2, maxlens=maxlens)
    ranges1.conjunct_(ranges2)
    assert repr(ranges1) == result


@pytest.mark.xfail(raises=AssertionError)
def test_parse_improper_version() -> None:
    r"""
    Test parsing an improper version message.

    Args
    ----

    Returns
    -------
    """
    # An arbitrary improper version message.
    pipord.Version("0.1xxx")


@pytest.mark.xfail(raises=RuntimeError)
def test_parse_improper_literal() -> None:
    r"""
    Test parsing an improper literal message.

    Args
    ----

    Returns
    -------
    """
    # An arbitrary improper version literal message.
    pipord.Literal("=1.7")


def test_main(*, tmpdir: str) -> None:
    r"""
    Test main program.

    Args
    ----
    - tmpdir
        Temporary directory for this test.
        It is automatically provided by PyTest, so its value should not be explicitly defined.

    Returns
    -------
    """
    # Move essential file to temporary directory for inplace I/O.
    src = os.path.join(os.path.abspath(os.path.dirname(__file__)), "fixture", "pipord")
    dst = str(tmpdir)
    for filename in ["dependencies.json"]:
        # Copy each essential file for current test with inplace I/O.
        shutil.copyfile(os.path.join(src, filename), os.path.join(dst, filename))

    # Call main program with arbitrary arguments.
    pipord.main([dst, "--inspect", "tomli"])
