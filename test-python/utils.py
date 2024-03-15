# Import Python packages.
import importlib.util as imputil
import os
import sys
from types import ModuleType


def rcimport(name: str, /) -> ModuleType:
    r"""
    Runtime command import.

    Args
    ----
    - name
        Module name.

    Returns
    -------
    - module
        Module.
    """
    # Load module from path.

    path = os.path.join(
        os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "src-python")),
        "{:s}.py".format(name),
    )
    spec = imputil.spec_from_file_location(name, path)
    assert spec is not None
    module = imputil.module_from_spec(spec)
    sys.modules[name] = module
    loader = spec.loader
    assert loader is not None
    loader.exec_module(module)
    return module
