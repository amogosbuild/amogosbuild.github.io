# Reject incorrect root ownership before creating either a live filesystem or an ISO.
import argparse
import os
import pathlib
import re
import stat
import subprocess


def directory(path):
    descriptor=os.open(path,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW)
    try:
        info=os.fstat(descriptor)
        if (info.st_uid,info.st_gid,stat.S_IMODE(info.st_mode))!=(0,0,0o755):
            raise ValueError('Filesystem root must be root:root with mode 0755: '+str(path))
    finally:
        os.close(descriptor)


def squashfs(path):
    result=subprocess.run(['unsquashfs','-lln','-max-depth','0',str(path)],check=True,capture_output=True,text=True)
    lines=[line for line in result.stdout.splitlines() if re.search(r'\s+squashfs-root$',line)]
    if len(lines)!=1 or not re.fullmatch(r'drwxr-xr-x\s+0/0\s+\d+\s+\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}\s+squashfs-root',lines[0]):
        raise ValueError('SquashFS root must be root:root with mode 0755: '+str(path))


def main():
    parser=argparse.ArgumentParser(description='Verify AmogOS filesystem root metadata without changing it.')
    parser.add_argument('--directory',type=pathlib.Path)
    parser.add_argument('--squashfs',type=pathlib.Path)
    arguments=parser.parse_args()
    if arguments.directory is None and arguments.squashfs is None:
        parser.error('Supply --directory or --squashfs.')
    if arguments.directory is not None:
        directory(arguments.directory)
    if arguments.squashfs is not None:
        squashfs(arguments.squashfs)
    print('AmogOS root ownership verified.')


if __name__=='__main__':
    main()
