# Exact incompatible publisher artifacts offer a working replacement without blocking future fixed uploads.
MESSAGE="This unofficial VLC AppImage is incomplete or incompatible with Debian. Choose the portable VLC Media Player AppImage instead."
BROKEN={"42cc4eae43b37936145af364dab8f530":MESSAGE,"67e3e247dd8e6a8841a97efba5e60fb5":MESSAGE}
BROKEN_SHA256={"7ca86bcb7c19694b89c9f65241c2c7d99ee57ef5c1dc08053c1182f2eb62e101","3e7566ad730078daa713439c5ef97ca58dd25d702dc5bb962b71fc2518fda413"}


def reason(item,index):
    return BROKEN.get(str(item.get("downloadmd5sum"+str(index),"")).lower(),"")
