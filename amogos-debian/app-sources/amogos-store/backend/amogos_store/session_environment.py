# Recover missing display endpoints only from the current user's running desktop session.
import os
import pathlib
import re
import stat
import subprocess


FIELDS=("DISPLAY","WAYLAND_DISPLAY","XAUTHORITY","DBUS_SESSION_BUS_ADDRESS","XDG_RUNTIME_DIR","XDG_SESSION_TYPE","XDG_CURRENT_DESKTOP","KDE_FULL_SESSION","KDE_SESSION_VERSION")


def display_available(env):
    value=env.get("DISPLAY","")
    match=re.fullmatch(r"(?:unix/)?:(\d+)(?:\.\d+)?",value)
    return bool(match and pathlib.Path("/tmp/.X11-unix/X"+match[1]).is_socket())


def wayland_available(env):
    value=env.get("WAYLAND_DISPLAY","")
    if not value:
        return False
    path=pathlib.Path(value)
    if not path.is_absolute():
        path=pathlib.Path(env.get("XDG_RUNTIME_DIR","/run/user/"+str(os.getuid())))/path
    try:
        info=path.stat()
        return info.st_uid==os.getuid() and stat.S_ISSOCK(info.st_mode)
    except OSError:
        return False


def desktop_environments():
    uid=os.getuid()
    for directory in pathlib.Path("/proc").iterdir():
        if not directory.name.isdigit():
            continue
        try:
            if directory.stat().st_uid!=uid or (directory/"comm").read_text().strip() not in ("plasmashell","kwin_wayland","kwin_x11","gnome-shell","xfce4-session"):
                continue
            with (directory/"environ").open("rb") as file:
                raw=file.read(65536)
            env=dict(item.decode(errors="replace").split("=",1) for item in raw.split(b"\0") if b"=" in item)
            if os.environ.get("XDG_SESSION_ID") and env.get("XDG_SESSION_ID")!=os.environ["XDG_SESSION_ID"]:
                continue
            yield env
        except (OSError,ValueError):
            continue


def environment():
    env=dict(os.environ)
    for variable in ("QT_PLUGIN_PATH","QT_QPA_PLATFORM_PLUGIN_PATH","QML2_IMPORT_PATH","QML_IMPORT_PATH"):
        env.pop(variable,None)
    runtime=pathlib.Path("/run/user/"+str(os.getuid()))
    if not env.get("XDG_RUNTIME_DIR") and runtime.is_dir() and runtime.stat().st_uid==os.getuid():
        env["XDG_RUNTIME_DIR"]=str(runtime)
    bus=pathlib.Path(env.get("XDG_RUNTIME_DIR",str(runtime)))/"bus"
    if not env.get("DBUS_SESSION_BUS_ADDRESS") and bus.is_socket() and bus.stat().st_uid==os.getuid():
        env["DBUS_SESSION_BUS_ADDRESS"]="unix:path="+str(bus)
    if not display_available(env) or (env.get("XDG_SESSION_TYPE")=="wayland" and not wayland_available(env)):
        candidates=list(desktop_environments())
        if env.get("DBUS_SESSION_BUS_ADDRESS"):
            try:
                result=subprocess.run(["systemctl","--user","show-environment"],env=env,capture_output=True,text=True,timeout=3)
                if result.returncode==0:
                    candidates.append(dict(line.split("=",1) for line in result.stdout.splitlines() if "=" in line))
            except (OSError,subprocess.TimeoutExpired):
                pass
        for candidate in candidates:
            if not display_available(env) and display_available(candidate):
                for key in ("DISPLAY","XAUTHORITY"):
                    if candidate.get(key):env[key]=candidate[key]
            if not wayland_available(env) and wayland_available(candidate):
                for key in ("WAYLAND_DISPLAY","XDG_RUNTIME_DIR","XDG_SESSION_TYPE"):
                    if candidate.get(key):env[key]=candidate[key]
            for key in FIELDS:
                if key in ("DISPLAY","WAYLAND_DISPLAY","XAUTHORITY","XDG_RUNTIME_DIR"):
                    continue
                if not env.get(key) and candidate.get(key):env[key]=candidate[key]
    return env
