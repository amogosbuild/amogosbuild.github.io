# Prefer matching binaries from the selected source package without pinning unrelated system dependencies.
from .apt_catalog import origin_key, origins


def prefer_family(cache, version, repo):
    policy=cache._depcache.policy
    for package in cache:
        match=next((v for v in package.versions if v.source_name==version.source_name and v.source_version==version.source_version and any(origin_key(o)==repo for o in origins(v))),None)
        if match:
            policy.create_pin("Version",package.name,match.version,990)
    policy.init_defaults()
    cache._depcache.init()
