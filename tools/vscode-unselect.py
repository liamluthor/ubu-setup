#!/usr/bin/env python3
"""Reset workbench.colorTheme if, and only if, it still names ours.

Split out of uninstall.sh rather than inlined as a heredoc: the shell already
nests one heredoc there, and a second delimiter inside it terminates the outer
one early. Prints RESET / NOTOURS / UNPARSEABLE.
"""
import json
import sys

path = sys.argv[1]
try:
    data = json.loads(open(path).read())
except Exception:
    print('UNPARSEABLE')
    sys.exit(0)

if not isinstance(data, dict) or data.get('workbench.colorTheme') != 'Synthwave':
    print('NOTOURS')
    sys.exit(0)

data['workbench.colorTheme'] = 'Dark Modern'
with open(path, 'w') as f:
    json.dump(data, f, indent=4)
    f.write('\n')
print('RESET')
