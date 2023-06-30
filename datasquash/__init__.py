from importlib.metadata import PackageNotFoundError, version

try:
    __version__ = version("DataSquash")
except PackageNotFoundError:
    # package is not installed
    pass
