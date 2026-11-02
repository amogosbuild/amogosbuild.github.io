# Only a system service reads private job requests and records completion after package checks finish.
import json
import os
import pathlib
import signal
import sys
import time

sys.path.insert(0,str(pathlib.Path(__file__).resolve().parent))
from amogos_store import apt_transactions,flatpak_transactions,jobs,runtime


def main():
    runtime.require_root()
    if len(sys.argv)!=2:
        raise runtime.StoreError("Choose one background transaction.")
    folder=jobs.ROOT/jobs.identity(sys.argv[1])
    info=folder.lstat()
    if folder.is_symlink() or info.st_uid!=0:
        raise runtime.StoreError("The background transaction request is invalid.")
    private=jobs.load(folder/"request.json")
    state=jobs.load(folder/"state.json")
    if not private or not state or private["action"] not in jobs.ACTIONS:
        raise runtime.StoreError("The background transaction is unavailable.")
    os.environ["PKEXEC_UID"]=str(private["owner"])
    def record(event):
        state.update(message=event.get("message","Applying package changes"),progress=event.get("progress"),updatedAt=time.time())
        if event.get("error"):state["error"]=True
        with (folder/"events.jsonl").open("a") as output:
            if output.tell()<2*1024*1024 or event.get("done") or event.get("error"):
                output.write(json.dumps(event)+"\n")
        jobs.write_state(folder,state)
    def interrupted(signum,frame):
        raise runtime.StoreError("Package configuration was interrupted. Use Repair interrupted installation in Updates.")
    signal.signal(signal.SIGTERM,interrupted)
    signal.signal(signal.SIGHUP,signal.SIG_IGN)
    runtime.EVENT_SINK=record
    state.update(status="running",updatedAt=time.time())
    jobs.write_state(folder,state)
    try:
        action=private["action"]
        if action=="apt-apply":apt_transactions.apply(private["request"])
        elif action=="flatpak-apply":flatpak_transactions.apply(private["request"])
        else:apt_transactions.refresh()
    except BaseException as error:
        state.update(status="failed",done=False,error=True)
        record(dict(message=str(error),error=True))
        return 1
    state.update(status="completed",done=True,error=False,progress=1)
    record(dict(message=state.get("message","Package changes complete."),progress=1,done=True))
    return 0


if __name__=="__main__":
    raise SystemExit(main())
