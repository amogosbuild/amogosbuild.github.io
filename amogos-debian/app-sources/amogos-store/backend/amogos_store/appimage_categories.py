# AppImageHub's application taxonomy maps to registered desktop menu categories.
GROUPS = [
    (("AudioVideo", "Audio"), {237,397,393,536,396,394,395}, ("audio","music","dj apps","mp3","radio")),
    (("AudioVideo", "Video"), {525,485,238,484,483,482,524}, ("video","screen record","tv &","webcam")),
    (("Education",), {545,241}, ("education","e-learning","learning")),
    (("Science",), {247}, ("science",)),
    (("Game",), {202,203,204,577,522,578,691,579,580,205,206}, ("game","arcade","board","chess","emulation","jump n run","racing","shooter","shoot em up","tactics")),
    (("Graphics",), {527,239,528,576,529}, ("graphic","image view","screenshot")),
    (("Network",), {492,248,250,249,541,535,537,539,242,251,255}, ("internet","browser","chat","email","ftp","torrent","vpn","telephony","network","phone apps")),
    (("Office",), {534,531,235,236,521,222,530,543}, ("office","crypto","ebook","financial","groupware","notes","pdf","printing")),
    (("Development",), {234,243,520,253,254,252}, ("database","developer","ides","qt ")),
    (("System",), {542,246,532,245,538}, ("system","security","virtualization","iot")),
    (("Utility", "TextEditor"), {240}, ("text editor",)),
    (("System", "TerminalEmulator"), {533}, ("terminal",)),
    (("Utility",), {540,244}, ("file management","utilit")),
]


def categories_for(item):
    value=str(item.get("typeid") or item.get("categoryid") or "")
    identity=int(value) if value.isdigit() else None
    for categories,identities,_ in GROUPS:
        if identity in identities:
            return list(categories)
    name=str(item.get("typename") or "").casefold()
    for categories,_,words in GROUPS:
        if any(word in name for word in words):
            return list(categories)
    return ["Utility"]


def in_category(item, category):
    values=categories_for(dict(typeid=item.get("id"),typename=item.get("name")))
    return category in values or (category=="Utility" and "System" in values) or (category=="Education" and "Science" in values)
