// Legacy signature transforms supplement the direct InnerTube and HLS playback clients.
String? decodeSignature(String source, String signature) {
  final function = RegExp(
    r'(\w+)=function\(\w+\)\{(\w+)=\2\.split\(\x22{2}\);.*?return\s+\2\.join\(\x22{2}\)\}',
  ).firstMatch(source)?.group(0);
  if (function == null) return null;
  final object = RegExp(r'([\$_\w]+)\.\w+\(\w+,\d+\);')
      .firstMatch(function)
      ?.group(1);
  if (object == null) return null;
  final definition = RegExp(
    'var\\s+${RegExp.escape(object)}=\\{(.*?)\\};',
    dotAll: true,
  ).firstMatch(source)?.group(1);
  if (definition == null) return null;
  var chars = signature.split(''), found = false;
  for (final statement in function.split(';')) {
    final call = RegExp(r'\w+(?:\.|\[)("?\w+"?)\]?\(\w+(?:,(\d+))?\)')
        .firstMatch(statement);
    if (call == null) continue;
    final method = call.group(1)!.replaceAll('"', '');
    final body = RegExp(
      '${RegExp.escape(method)}:function\\([^)]*\\)\\{([^}]+)\\}',
    ).firstMatch(definition)?.group(1);
    if (body == null) continue;
    final count = int.tryParse(call.group(2) ?? '') ?? 0;
    if (body.contains('.reverse(')) {
      chars = chars.reversed.toList();
      found = true;
    } else if (body.contains('.splice(') || body.contains('.slice(')) {
      chars = chars.skip(count).toList();
      found = true;
    } else if (body.contains('%') && chars.isNotEmpty) {
      final at = count % chars.length, first = chars.first;
      chars[0] = chars[at];
      chars[at] = first;
      found = true;
    }
  }
  return found ? chars.join() : null;
}
