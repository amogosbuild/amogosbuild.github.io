# The versioned 2.1 migration preserves vendor identity backups and never downgrades an updated system.
import os
import json
import pathlib
import re
import shlex
import subprocess
import tempfile
from urllib.parse import urlsplit


def fields(path):
    values={}
    for line in path.read_text().splitlines():
        if '=' in line and not line.startswith('#'):
            key,value=line.split('=',1)
            try:
                values[key]=' '.join(shlex.split(value))
            except ValueError:
                continue
    return values


def atomic(path,value):
    path.parent.mkdir(parents=True,exist_ok=True)
    descriptor,temporary=tempfile.mkstemp(prefix='.'+path.name+'.',dir=path.parent)
    try:
        with os.fdopen(descriptor,'w') as stream:
            stream.write(value)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary,0o644)
        os.replace(temporary,path)
    finally:
        pathlib.Path(temporary).unlink(missing_ok=True)


def repositories():
    import apt_pkg
    apt_pkg.init()
    sources=apt_pkg.SourceList()
    sources.read_main_list()
    required=[('deb.debian.org','/debian','trixie'),('deb.debian.org','/debian','trixie-updates'),('security.debian.org','/debian-security','trixie-security')]
    missing=[]
    for host,prefix,suite in required:
        matching=[source for source in sources.list if urlsplit(source.uri).hostname==host and urlsplit(source.uri).path.rstrip('/')==prefix and source.dist==suite]
        has_main=any(any('/main ' in index.describe for index in source.index_files) for source in matching)
        if not has_main:
            options='' if matching else '[signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] '
            missing.append('deb '+options+'https://'+host+prefix+' '+suite+' main contrib non-free non-free-firmware')
    if missing:
        path=pathlib.Path('/etc/apt/sources.list.d/amogos-debian-repair.list')
        existing=path.read_text() if path.exists() else ''
        atomic(path,existing.rstrip()+'\n'+'\n'.join(missing)+'\n')


def main():
    if os.geteuid()!=0:
        raise SystemExit('Run the AmogOS system update with administrator privileges.')
    canonical=pathlib.Path('/usr/lib/os-release')
    current=fields(pathlib.Path('/etc/os-release'))
    if current.get('ID')!='amogos':
        raise SystemExit('This system migration applies only to AmogOS.')
    version=current.get('OS_VERSION') or current.get('VERSION_ID','0')
    maintenance=subprocess.run(['/usr/libexec/amogos-root-ownership','--mark-reboot'],check=True,capture_output=True,text=True)
    repaired=json.loads(maintenance.stdout).get('changed',False)
    if subprocess.run(['dpkg','--compare-versions',version,'ge','2.1']).returncode==0:
        print('AmogOS root ownership corrected. Restart to restore desktop graphics.' if repaired else 'You are already on the latest AmogOS version')
        return
    repositories()
    owner=subprocess.check_output(['dpkg-divert','--listpackage','/usr/lib/os-release'],text=True).strip()
    if owner not in ('','LOCAL'):
        raise SystemExit('Another package manages the OS identity diversion; refusing to replace it.')
    if not owner:
        subprocess.run(['dpkg-divert','--local','--no-rename','--add','/usr/lib/os-release'],check=True)
    data=fields(canonical) if canonical.exists() else dict(current)
    data.update(PRETTY_NAME='AmogOS 2 Pro 2.1 (toppat)',NAME='AmogOS 2 Pro',VERSION_ID='2.1',OS_VERSION='2.1',VERSION='2.1 (toppat)',ID='amogos')
    content=''.join(key+'='+shlex.quote(value)+'\n' for key,value in data.items())
    etc=pathlib.Path('/etc/os-release')
    if not etc.is_symlink() or os.readlink(etc)!='../usr/lib/os-release':
        temporary=etc.with_name('.os-release-amogos')
        temporary.unlink(missing_ok=True)
        temporary.symlink_to('../usr/lib/os-release')
        os.replace(temporary,etc)
    atomic(pathlib.Path('/etc/amogos-release'),'2.1\n')
    atomic(pathlib.Path('/etc/lsb-release'),'DISTRIB_ID=AmogOS\nDISTRIB_RELEASE=2.1\nDISTRIB_CODENAME=chocolatier\nDISTRIB_DESCRIPTION="AmogOS 2 Pro 2.1 (toppat)"\n')
    atomic(pathlib.Path('/etc/issue'),'AmogOS 2 Pro 2.1 (toppat) \\n \\l\n\n')
    atomic(pathlib.Path('/etc/issue.net'),'AmogOS 2 Pro 2.1 (toppat)\n')
    if pathlib.Path('/bin/systemctl').exists():
        subprocess.run(['systemctl','enable','amogos-installed-cleanup.service'],check=True)
    atomic(pathlib.Path('/run/reboot-required'),'Restart required to refresh AmogOS desktop graphics support.\n')
    packages=pathlib.Path('/run/reboot-required.pkgs')
    existing=packages.read_text().splitlines() if packages.exists() else []
    atomic(packages,'\n'.join(dict.fromkeys([*existing,'amogos-update']))+'\n')
    atomic(canonical,content)
    if pathlib.Path('/run/systemd/system').exists():
        subprocess.run(['systemctl','start','--no-block','amogos-installed-cleanup.service'],check=False)
    print('AmogOS 2.1 system update applied.')


if __name__=='__main__':
    main()
