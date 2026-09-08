"""Package locally signed A/B, blink or wallpaper-level experiments. Does not launch apps."""
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys

root = Path(__file__).resolve().parent.parent
source = root / 'build/DerivedData/Build/Products/Release/MaskedNotch.app'
output = root / 'build/Variants'
output.mkdir(parents=True, exist_ok=True)
if '--desktop' in sys.argv:
    variants = [('Desktop', None)]
elif '--blink' in sys.argv:
    variants = [('Blink', 'blink')]
else:
    variants = [('A', 'redraw'), ('B', 'order')]
for letter, phase in variants:
    app = output / f'Masked Notch {letter}.app'
    if app.exists():
        shutil.rmtree(app)
    shutil.copytree(source, app)
    info = app / 'Contents/Info.plist'
    data = plistlib.loads(info.read_bytes())
    data.update(CFBundleDisplayName=f'Masked Notch {letter}',
                CFBundleName=f'Masked Notch {letter}',
                CFBundleIdentifier=f'local.MaskedNotch.{letter}')
    if letter == 'Desktop':
        data['MaskedNotchDesktopPlacement'] = 'aboveWallpaper'
        data['MaskedNotchLayeredBands'] = True
        data.pop('MaskedNotchRefreshVariant', None)
    else:
        data['MaskedNotchRefreshVariant'] = phase
        data.pop('MaskedNotchDesktopPlacement', None)
        data.pop('MaskedNotchLayeredBands', None)
    info.write_bytes(plistlib.dumps(data))
    subprocess.run(['codesign', '--force', '--sign', '-', '--options', 'runtime', str(app)], check=True)
    subprocess.run(['codesign', '--verify', '--strict', str(app)], check=True)
    print(app)
