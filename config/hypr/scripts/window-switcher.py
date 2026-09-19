#!/usr/bin/env python3
"""MRU window picker for Hyprland; all window data stays in memory."""
import json
from pathlib import Path
import re
import subprocess
import sys

def main():
    windows = json.loads(subprocess.check_output(['hyprctl', 'clients', '-j']))
    windows = [w for w in windows if w.get('mapped', True) and not w.get('hidden', False) and re.fullmatch(r'0x[0-9a-fA-F]+', w.get('address', ''))]
    windows.sort(key=lambda w: w.get('focusHistoryID', 999999) if w.get('focusHistoryID', -1) >= 0 else 999999)
    if not windows:
        return
    backwards = '--backward' in sys.argv
    selected = len(windows) - 1 if backwards else min(1, len(windows) - 1)
    rows = []
    for w in windows:
        app = w.get('class') or w.get('initialClass') or 'Window'
        title = w.get('title') or app
        workspace = w.get('workspace', {}).get('name', '?')
        label = f'{app} — {title}  ·  Workspace {workspace}'
        label = label.replace('\n', ' ').replace('\r', ' ').replace('\0', '')
        icon = app.replace('\n', '').replace('\0', '').replace('\x1f', '')
        rows.append(label + '\0icon\x1f' + icon)
    cmd = ['rofi', '-no-config', '-global-kb', '-dmenu', '-i', '-no-custom', '-format', 'i', '-show-icons',
           '-p', 'Windows', '-selected-row', str(selected),
           '-theme', str(Path(__file__).with_name('window-switcher.rasi')),
           '-kb-element-next', '', '-kb-element-prev', '',
           '-kb-row-tab', '', '-kb-mode-next', '', '-kb-mode-previous', '',
           '-kb-move-char-back', 'Control+b', '-kb-move-char-forward', 'Control+f',
           '-kb-row-down', 'Down,Right,Super+Down,Super+Right,Tab,Super+Tab',
           '-kb-row-up', 'Up,Left,Super+Up,Super+Left,ISO_Left_Tab,Super+ISO_Left_Tab,Super+Shift+Tab',
           '-kb-accept-entry', '!Super_L,!Super_R,Return,KP_Enter',
           '-kb-cancel', 'Escape']
    result = subprocess.run(cmd, input='\n'.join(rows)+'\n', text=True, capture_output=True)
    if result.returncode != 0:
        if result.stderr:
            print(result.stderr, file=sys.stderr)
        return
    try:
        index = int(result.stdout.strip())
    except ValueError:
        return
    if 0 <= index < len(windows):
        address = windows[index]['address']
        subprocess.run(['hyprctl', 'dispatch', f'hl.dsp.focus({{ window = "address:{address}" }})'], check=True)

if __name__ == '__main__':
    main()
