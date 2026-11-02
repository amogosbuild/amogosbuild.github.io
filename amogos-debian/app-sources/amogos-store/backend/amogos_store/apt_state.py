# Pending dpkg configuration is included in a repair review before any maintainer scripts are resumed.
from .runtime import run


CONFIGURABLE={"unpacked","half-configured","triggers-awaited","triggers-pending"}


def pending():
    fields=chr(36)+"{binary:Package}\t"+chr(36)+"{Version}\t"+chr(36)+"{db:Status-Status}\n"
    result=run(["dpkg-query","-W","-f="+fields])
    values=[]
    for line in result.stdout.splitlines():
        parts=line.split("\t")
        if len(parts)==3 and parts[2] in CONFIGURABLE:
            values.append(dict(id=parts[0],version=parts[1],state=parts[2]))
    return sorted(values,key=lambda item:item["id"])
