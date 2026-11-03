# Normalize only the AmogOS root inode so runtime directories can be created safely.
import json
import os
import pathlib
import shlex
import stat
import sys


def repair(path):
    descriptor=os.open(path,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW)
    try:
        before=os.fstat(descriptor)
        changed=(before.st_uid,before.st_gid,stat.S_IMODE(before.st_mode))!=(0,0,0o755)
        if changed:
            os.fchown(descriptor,0,0)
            os.fchmod(descriptor,0o755)
        after=os.fstat(descriptor)
        if (after.st_uid,after.st_gid,stat.S_IMODE(after.st_mode))!=(0,0,0o755):
            raise RuntimeError('The AmogOS filesystem root could not be normalized.')
        return changed
    finally:
        os.close(descriptor)


def mark_reboot():
    path=pathlib.Path('/run/reboot-required')
    if not path.exists():
        path.write_text('Restart required to restore AmogOS desktop graphics after correcting root ownership.\n')
    packages=pathlib.Path('/run/reboot-required.pkgs')
    values=packages.read_text().splitlines() if packages.exists() else []
    packages.write_text('\n'.join(dict.fromkeys([*values,'amogos-system']))+'\n')


def main():
    if os.geteuid()!=0:
        raise SystemExit('Administrator privileges are required.')
    if sys.argv[1:] not in ([],['--mark-reboot']):
        raise SystemExit('Unsupported root ownership operation.')
    release=pathlib.Path('/etc/os-release')
    identity={}
    for line in release.read_text().splitlines():
        if '=' in line and not line.startswith('#'):
            key,value=line.split('=',1)
            identity[key]=' '.join(shlex.split(value))
    if identity.get('ID')!='amogos':
        print(json.dumps(dict(changed=False,skipped=True)))
        return
    changed=repair(pathlib.Path('/'))
    if changed and '--mark-reboot' in sys.argv:
        mark_reboot()
    print(json.dumps(dict(changed=changed)))


if __name__=='__main__':
    main()
