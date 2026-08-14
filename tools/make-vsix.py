#!/usr/bin/env python3
"""Pack an extension directory into a .vsix.

    python3 tools/make-vsix.py <extension-dir> <output.vsix>

Needed because dropping a folder into ~/.vscode/extensions/ does not work:
VS Code loads only what is listed in that directory's extensions.json, which
it writes itself, so a hand-placed folder is silently ignored — `code
--list-extensions` will not show it and the theme never appears in the picker.
Installing through `code --install-extension file.vsix` is what registers it.

A .vsix is an ordinary zip with two bits of packaging metadata beside the
extension payload. No vsce/npm needed.
"""
import json
import os
import sys
import zipfile

CONTENT_TYPES = '''<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="json" ContentType="application/json"/>
  <Default Extension="xml" ContentType="text/xml"/>
  <Default Extension="md" ContentType="text/markdown"/>
</Types>
'''

MANIFEST = '''<?xml version="1.0" encoding="utf-8"?>
<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011">
  <Metadata>
    <Identity Language="en-US" Id="{name}" Version="{version}" Publisher="{publisher}"/>
    <DisplayName>{display}</DisplayName>
    <Description xml:space="preserve">{description}</Description>
    <Tags>theme,color-theme</Tags>
    <Categories>Themes</Categories>
    <GalleryFlags>Public</GalleryFlags>
    <Properties>
      <Property Id="Microsoft.VisualStudio.Code.Engine" Value="{engine}"/>
      <Property Id="Microsoft.VisualStudio.Code.ExtensionDependencies" Value=""/>
    </Properties>
  </Metadata>
  <Installation>
    <InstallationTarget Id="Microsoft.VisualStudio.Code"/>
  </Installation>
  <Dependencies/>
  <Assets>
    <Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true"/>
  </Assets>
</PackageManifest>
'''


def main():
    if len(sys.argv) != 3:
        raise SystemExit(__doc__.strip())
    src, out = sys.argv[1], sys.argv[2]

    pkg = json.load(open(os.path.join(src, 'package.json')))
    fields = {
        'name': pkg['name'],
        'version': pkg['version'],
        'publisher': pkg['publisher'],
        'display': pkg.get('displayName', pkg['name']),
        'description': pkg.get('description', ''),
        'engine': pkg.get('engines', {}).get('vscode', '^1.70.0'),
    }

    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    # Deterministic: fixed timestamps and sorted entries, so rebuilding an
    # unchanged theme produces an identical file and the module can tell
    # "nothing to do" from "needs reinstalling".
    with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
        def write(arcname, data):
            info = zipfile.ZipInfo(arcname, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            z.writestr(info, data)

        write('[Content_Types].xml', CONTENT_TYPES)
        write('extension.vsixmanifest', MANIFEST.format(**fields))
        for root, dirs, files in os.walk(src):
            dirs.sort()
            for f in sorted(files):
                full = os.path.join(root, f)
                rel = os.path.relpath(full, src)
                write(f'extension/{rel}', open(full, 'rb').read())

    print(f"{out}  ({fields['publisher']}.{fields['name']}-{fields['version']})")


if __name__ == '__main__':
    main()
