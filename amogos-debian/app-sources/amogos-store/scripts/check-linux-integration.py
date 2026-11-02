# Real package tests require the isolated build chroot and never accept the VPS host or ISO rootfs.
import json
import os
import pathlib
import subprocess

if os.environ.get("AMOGOS_STORE_TEST_ROOT")!="bootstrap" or os.environ.get("container")!="chocolatier" or not pathlib.Path("/work/rootfs/etc/os-release").is_file() or 'ID=debian' not in pathlib.Path("/etc/os-release").read_text():
    raise SystemExit("Run only through enter-bootstrap with AMOGOS_STORE_TEST_ROOT=bootstrap.")
CLI=["/usr/bin/python3","-I","/work/apps/app_store/backend/cli.py"]


def request(action,body=None,user=False,stream=False,expect_error=False):
    command=(["runuser","-u","storetest","--"] if user else [])+CLI+[action]
    result=subprocess.run(command,input=json.dumps(body or {}),text=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=1800)
    if expect_error:
        if result.returncode==0:
            raise AssertionError("An expired or consumed review was accepted.")
        return
    if result.returncode:
        print(result.stdout[-6000:]);print(result.stderr[-3000:])
        raise RuntimeError(action+" failed")
    if stream:
        events=[json.loads(line) for line in result.stdout.splitlines() if line.strip()]
        if not any(event.get("done") is True for event in events):
            raise AssertionError("The operation never completed.")
        print(action,"completed",events[-1]["message"],flush=True)
        return events
    return json.loads(result.stdout)


query=request("catalog",dict(source="all",query="krita"))
sources={v["source"] for v in query["items"]}
assert sources=={"deb","flatpak","appimage"},query["warnings"]
print("Live catalogs: APT, Flathub, AppImageHub passed",flush=True)
alternatives=request("alternatives",dict(source="flatpak",id="org.kde.krita"))
assert {v["source"] for v in alternatives["items"]}==sources,alternatives
print("Krita source choices contain all three available formats",flush=True)
repo=next(v["repo"] for v in alternatives["items"] if v["source"]=="deb")
filtered=request("catalog",dict(source="deb",query="krita",repo=repo))
assert filtered["items"] and all(v["repo"]==repo for v in filtered["items"])
print("APT repository filtering passed",flush=True)
name="hello"
status=subprocess.run(["dpkg-query","-W","-f=${db:Status-Status}",name],text=True,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL)
if status.stdout.strip()=="installed":
    raise SystemExit("The test package hello is already installed; preserve it and choose another fixture.")
plan=request("apt-plan",dict(id=name,operation="install"))
assert any(v["id"]==name and v["action"]=="install" for v in plan["changes"])
request("apt-apply",dict(token=plan["token"]),stream=True)
assert subprocess.check_output(["dpkg-query","-W","-f=${db:Status-Status}",name],text=True).strip()=="installed"
request("apt-apply",dict(token=plan["token"]),expect_error=True)
plan=request("apt-plan",dict(id=name,operation="remove"))
request("apt-apply",dict(token=plan["token"]),stream=True)
print("APT install, remove, and consumed-token refusal passed",flush=True)
plan=request("flatpak-plan",dict(id="org.gnome.Calculator",operation="install"))
request("flatpak-apply",dict(token=plan["token"]),stream=True)
assert "org.gnome.Calculator" in subprocess.check_output(["flatpak","--system","list","--app","--columns=application"],text=True)
plan=request("flatpak-plan",dict(id="org.gnome.Calculator",operation="remove"))
request("flatpak-apply",dict(token=plan["token"]),stream=True)
print("Real system Flatpak install and remove passed",flush=True)
item=request("details",dict(source="appimage",id="2380771"),user=True)
choice=item["downloads"][0]
request("appimage-install",dict(id=item["id"],download=choice["number"],version=choice["version"]),user=True,stream=True)
home=pathlib.Path("/home/storetest")
manifest=json.loads((home/".local/share/amogos-store/appimages.json").read_text())
entry=manifest[item["id"]]
assert pathlib.Path(entry["path"]).is_file() and pathlib.Path(entry["desktop"]).is_file() and len(entry["sha256"])==64
request("appimage-remove",dict(id=item["id"]),user=True,stream=True)
assert not pathlib.Path(entry["path"]).exists() and not pathlib.Path(entry["desktop"]).exists()
print("Real AppImageHub download, validation, integration, and removal passed",flush=True)
print("STORE_INTEGRATION_PASSED",flush=True)
