"""Hyprland input adapter used by bifrostctl and the existing compositor backend.
Reads compositor state, udev and libinput capabilities; never reads input events.
All persistent writes still go through config.json and generate_hypr().
"""
from __future__ import annotations
import ctypes as C
import ctypes.util
import json
import os
import re
import subprocess
import shlex
import fcntl
import struct
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOUCHPAD_FIELDS = {'natural_scroll','scroll_factor','middle_button_emulation','tap_to_click','tap_and_drag','drag_lock','disable_while_typing','clickfinger_behavior'}

def run(args):
    try:
        p = subprocess.run(args, capture_output=True, text=True, timeout=8)
        return p.returncode, p.stdout
    except (OSError, subprocess.TimeoutExpired):
        return 1, ''

def fields():
    schema = json.loads((ROOT/'schema/input.json').read_text())
    setting = next((s for s in schema.get('settings', []) if s.get('key') == 'input.devices'), None)
    if not setting or 'deviceFields' not in setting:
        raise KeyError("input.devices.deviceFields")
    return setting['deviceFields']

def json_stream(text):
    decoder = json.JSONDecoder()
    while text.strip():
        text = text.lstrip()
        try: value, pos = decoder.raw_decode(text)
        except ValueError:
            text = text.split("\n", 1)[1] if "\n" in text else ""
            continue
        yield value
        text = text[pos:]

def device_nodes():
    result = []
    for event in sorted(Path('/sys/class/input').glob('event*')):
        try:
            name = (event/'device/name').read_text().strip()
            dev = (event/'dev').read_text().strip()
            props = dict(line[2:].split('=',1) for line in (Path('/run/udev/data')/('c'+dev)).read_text().splitlines() if line.startswith('E:') and '=' in line)
            kind = 'trackpad' if props.get('ID_INPUT_TOUCHPAD') == '1' else 'mouse' if props.get('ID_INPUT_MOUSE') == '1' else 'keyboard' if props.get('ID_INPUT_KEYBOARD') == '1' else ''
            if kind:
                result.append({'name': name, 'key':name.lower().replace(' ','-'), 'kind':kind, 'path':'/dev/input/'+event.name,'sysfs':str(event/'device'),'integration':props.get('ID_INPUT_TOUCHPAD_INTEGRATION','')})
        except (OSError, ValueError):
            continue
    return result

def kernel_capabilities(node):
    """Conservative libinput feature rules from actual kernel capabilities.
    No device-name guesses; uncertain/vendor-specific controls stay hidden.
    Prefer the libinput query when the seat permits opening its event node.
    """
    def bits(path):
        words=Path(path).read_text().split()
        width=64 if os.uname().machine.endswith('64') else 32
        mask=sum(int(w,16) << (width*i) for i,w in enumerate(reversed(words)))
        return {i for i in range(mask.bit_length()) if mask & (1<<i)}
    try:
        base=Path(node['sysfs'])
        keys=bits(base/'capabilities/key'); rel=bits(base/'capabilities/rel'); axes=bits(base/'capabilities/abs'); props=bits(base/'properties')
    except (OSError,ValueError): return None
    if node['kind']=='mouse' and {0,1}.issubset(rel):
        return {'accel':True,'profiles':['adaptive','flat'],'natural':bool({6,8}&rel),
                'leftHanded':{0x110,0x111}.issubset(keys),'middle':{0x110,0x111}.issubset(keys),
                'scrollMethods':['on_button_down','no_scroll'] if 0x112 in keys else [],
                'buttonScroll':0x112 in keys,'buttons':[0]+sorted(keys & set(range(0x110,0x118)))}
    if node['kind']=='trackpad' and {0x2f,0x35,0x36}.issubset(axes) and 0x145 in keys:
        fingers=4 if 0x14f in keys else 3 if 0x14e in keys else 2 if 0x14d in keys else 1
        return {'maxFingers':fingers,'accel':True,'profiles':['adaptive','flat'],'natural':True,
                'leftHanded':2 in props,'tap':True,
                'clickMethods':[False,True] if 2 in props and fingers>=2 else [],
                'scrollMethods':(['2fg'] if fingers>=2 else [])+['edge','no_scroll'],
                'gestures':fingers>=3,
                # External touchpads aren't paired with an internal keyboard.
                'dwt':node.get('integration')=='internal'}
    return None

class LibinputProbe:
    """Use the installed public C API, without event dispatch or device grabs."""
    def __init__(self):
        self.lib = C.CDLL(ctypes.util.find_library('input') or 'libinput.so.10')
        Open = C.CFUNCTYPE(C.c_int,C.c_char_p,C.c_int,C.c_void_p)
        Close = C.CFUNCTYPE(None,C.c_int,C.c_void_p)
        def open_device(path, flags, data):
            try: return os.open(os.fsdecode(path), flags | os.O_CLOEXEC)
            except OSError as e: return -e.errno
        self.open = Open(open_device)
        self.close = Close(lambda fd,data: os.close(fd))
        class Interface(C.Structure): _fields_=[('open',Open),('close',Close)]
        self.interface = Interface(self.open,self.close)
        self.lib.libinput_path_create_context.argtypes=[C.POINTER(Interface),C.c_void_p]
        self.lib.libinput_path_create_context.restype=C.c_void_p
        self.context = self.lib.libinput_path_create_context(C.byref(self.interface),None)
        self.lib.libinput_path_add_device.argtypes=[C.c_void_p,C.c_char_p]
        self.lib.libinput_path_add_device.restype=C.c_void_p
        self.lib.libinput_path_remove_device.argtypes=[C.c_void_p]
        self.lib.libinput_unref.argtypes=[C.c_void_p]
        # Suppress libinput's access-denied diagnostics; the UI reports unavailable.
        Log = C.CFUNCTYPE(None,C.c_void_p,C.c_int,C.c_char_p,C.c_void_p)
        self.log = Log(lambda *_: None)
        self.lib.libinput_log_set_handler.argtypes=[C.c_void_p,Log]
        self.lib.libinput_log_set_handler(self.context,self.log)

    def query(self, path):
        if not self.context: return None
        dev = self.lib.libinput_path_add_device(self.context,os.fsencode(path))
        if not dev: return None
        def val(name, *args):
            fn = getattr(self.lib,'libinput_device_'+name,None)
            if not fn: return 0
            fn.argtypes=[C.c_void_p]+[C.c_int]*len(args); fn.restype=C.c_int
            return fn(dev,*args)
        try:
            profiles=val('config_accel_get_profiles'); methods=val('config_scroll_get_methods'); clicks=val('config_click_get_methods')
            finger_count = min(3, val('config_tap_get_finger_count'))
            try:
                fd = os.open(path,os.O_RDONLY | os.O_NONBLOCK | os.O_CLOEXEC)
                try:
                    # EVIOCGABS(ABS_MT_SLOT): query slot count, not input events.
                    buf=fcntl.ioctl(fd,0x80184540+0x2f,bytes(24))
                    finger_count=struct.unpack('6i',buf)[2]+1
                finally: os.close(fd)
            except OSError: pass
            return {'buttons':[0]+[i for i in range(272,280) if val('pointer_has_button',i)],'maxFingers':finger_count,'accel':bool(val('config_accel_is_available')),
                    'profiles':[s for bit,s in [(2,'adaptive'),(1,'flat')] if profiles & bit],
                    'natural':bool(val('config_scroll_has_natural_scroll')),
                    'leftHanded':bool(val('config_left_handed_is_available')),
                    'middle':bool(val('config_middle_emulation_is_available')),
                    'tap':val('config_tap_get_finger_count') > 0,
                    'dwt':bool(val('config_dwt_is_available')),
                    'clickMethods':[v for bit,v in [(1,False),(2,True)] if clicks & bit],
                    'scrollMethods':[s for bit,s in [(1,'2fg'),(2,'edge'),(4,'on_button_down')] if methods & bit]+(['no_scroll'] if methods else []),
                    'buttonScroll':bool(methods & 4),
                    'gestures':bool(val('has_capability',5))}
        finally: self.lib.libinput_path_remove_device(dev)

    def close_context(self):
        if self.context: self.lib.libinput_unref(self.context); self.context=None

def xkb_catalog():
    try:
        root=ET.parse('/usr/share/X11/xkb/rules/evdev.xml').getroot()
        layouts=[]
        for layout in root.findall('./layoutList/layout'):
            name=layout.findtext('./configItem/name'); label=layout.findtext('./configItem/description')
            variants=[{'value':v.findtext('./configItem/name'),'label':v.findtext('./configItem/description')} for v in layout.findall('./variantList/variant')]
            layouts.append({'value':name,'label':label,'variants':variants})
        options=[{'value':o.findtext('./configItem/name'),'label':o.findtext('./configItem/description')} for o in root.findall('./optionList/group/option')]
        return {'layouts':layouts,'options':options}
    except (OSError,ET.ParseError): return {'layouts':[],'options':[]}

def query():
    code,text=run(['hyprctl','devices','-j'])
    try: raw=json.loads(text) if code == 0 else None
    except ValueError: raw=None
    if not isinstance(raw,dict): return {'devices':[],'error':'Input backend unavailable','catalog':xkb_catalog()}
    defs=fields()
    paths=sorted({('input.touchpad.' if kind=='trackpad' and f['key'] in TOUCHPAD_FIELDS else 'input.')+f['key'] for f in defs for kind in f['kinds']})
    _, text=run(['hyprctl','--batch','-j','; '.join('getoption '+k for k in paths)])
    globals={}
    for obj in json_stream(text):
        if isinstance(obj,dict) and 'option' in obj:
            globals[obj['option']]=next((obj[k] for k in ('bool','int','float','str') if k in obj),None)
    nodes=device_nodes()
    try: probe=LibinputProbe()
    except (OSError,AttributeError): probe=None
    devices=[]
    try:
        for group in ('keyboards','mice'):
            for d in raw.get(group,[]):
                name=d['name']; matches=[n for n in nodes if name==n['key'] or re.fullmatch(re.escape(n['key'])+r'-\d+',name)]
                candidates=[n for n in matches if (n['kind']=='keyboard')==(group=='keyboards')]
                node=candidates[0] if len(candidates)==1 else None
                kind='keyboard' if group=='keyboards' else node['kind'] if node else 'unknown'
                if kind=='unknown': continue  # Don't label unidentified pointer devices as mice.
                caps={} if kind=='keyboard' else probe.query(node['path']) if probe and node else None
                source = 'libinput'
                if caps is None and node:
                    caps = kernel_capabilities(node)
                    source = 'kernel'
                values={}
                for f in defs:
                    if kind not in f['kinds']: continue
                    prefix='input.touchpad.' if kind=='trackpad' and f['key'] in TOUCHPAD_FIELDS else 'input.'
                    v=globals.get(prefix+f['key'])
                    if v is None: continue
                    if isinstance(v,str) and v=='[[EMPTY]]': v=''
                    if f['type']=='bool' or f['key']=='clickfinger_behavior': v=bool(v)
                    values[f['key']]=v
                if kind=='mouse' and caps and caps.get('middle'):
                    values.setdefault('middle_button_emulation',False)
                if kind=='keyboard':
                    values.update(kb_layout=d.get('layout',''),kb_variant=d.get('variant',''),kb_options=d.get('options',''))
                devices.append({'name':name,'label':node['name'] if node else name,'kind':kind,'values':values,'capabilities':caps or {},'capabilitiesKnown':caps is not None,'capabilitySource':source,'activeLayout':d.get('active_layout_index',0),'activeKeymap':d.get('active_keymap',''),'main':d.get('main',False)})
    finally:
        if probe: probe.close_context()
    return {'devices':devices,'catalog':xkb_catalog(),'gestures':configured_gestures(),'error':''}

def lua(value):
    if isinstance(value,bool): return str(value).lower()
    if isinstance(value,(float,int)): return repr(value)
    if isinstance(value,str): return '"'+''.join('\\%03d'%ord(c) if ord(c)<32 else '\\\\' if c=='\\' else '\\"' if c=='"' else c for c in value)+'"'
    if isinstance(value,dict): return '{'+','.join('['+lua(k)+']='+lua(v) for k,v in value.items())+'}'
    raise ValueError('unsupported Lua value')

def generate(devices,gestures,active_layouts=None,gesture_actions=None):
    """Called only by the existing hypr generator, never a parallel apply path."""
    lines=['-- Per-device input (only explicitly edited fields)', 'state.input = state.input or {}', 'local next_input = '+lua(devices)]
    lines += ['for name, old in pairs(state.input) do', '  local next = next_input[name]', '  local restore = {name=name}', '  for key, value in pairs(old.original or {}) do', '    if not next or next.values[key] == nil then restore[key] = value end', '  end', '  hl.device(restore)', 'end', 'for name, device in pairs(next_input) do', '  local rule = {name=name}', '  for key, value in pairs(device.values) do rule[key] = value end', '  hl.device(rule)', 'end', 'state.input = next_input']
    # Native gesture declarations have no introspection/removal handle. Seed
    # ownership from literal declarations in the loaded config, never assume a
    # missing gesture exists (Hyprland reports unset of a missing slot as error).
    inherited={k:v['action'] for k,v in configured_gestures().items()}
    lines += ['state.input_gestures = state.input_gestures or {}',
              'state.input_gesture_base = state.input_gesture_base or '+lua(inherited),
              'state.input_gesture_live = state.input_gesture_live or (__bifrost_verify and {} or '+lua(inherited)+')',
              'local next_gestures = '+lua(gestures),
              'local function remove_gesture(key)',
              '  local action = state.input_gesture_live[key]',
              '  if action and action ~= "none" then',
              '    local fingers, direction = key:match("^(%d+):(.+)$")',
              '    pcall(hl.gesture, {fingers=tonumber(fingers), direction=direction, action="unset"})',
              '    state.input_gesture_live[key] = nil',
              '  end', 'end',
              'for key, _ in pairs(state.input_gestures) do remove_gesture(key) end',
              'for key, _ in pairs(next_gestures) do remove_gesture(key) end',
              'for key, _ in pairs(state.input_gestures) do',
              '  local original = state.input_gesture_base[key]',
              '  if next_gestures[key] == nil and original and original ~= "custom" then',
              '    local fingers, direction = key:match("^(%d+):(.+)$")',
              '    hl.gesture({fingers=tonumber(fingers), direction=direction, action=original})',
              '    state.input_gesture_live[key] = original', '  end', 'end']
    # gesture_actions (bifrostctl.gesture_actions): value -> a Hyprland
    # gesture action (native) or a Bifrost action run through its ipc.
    catalogue={g['value']:g for g in (gesture_actions or [])}
    # Hyprland refuses a gesture that an earlier, more general one on the
    # same fingers shadows (swipe > vertical/horizontal > up/down/left/right),
    # but not the other way round: register the specific ones first, so e.g.
    # 3:up and 3:swipe both work (up, and every other swipe).
    rank={'up':0,'down':0,'left':0,'right':0,'vertical':1,'horizontal':1,'swipe':2}
    for key,action in sorted(gestures.items(),key=lambda kv:(kv[0].split(':')[0],rank.get(kv[0].split(':')[1],3))):
        fingers,direction=key.split(':')
        spec='fingers='+fingers+', direction='+lua(direction)
        entry=catalogue.get(action,{'native':action})
        if entry.get('native')=='none': continue
        # pcall: Hyprland rejects a gesture another one shadows (e.g. 3:up
        # after 3:swipe); that must not abort the rest of the file (binds).
        # Only a gesture Hyprland took is live (removed on the next run).
        if 'ipc' in entry:
            command='bin .. '+lua('bifrost-ipc '+entry['ipc'])
            lines.append('if pcall(hl.gesture, {'+spec+', action=function() hl.exec_cmd('+command+') end}) then')
        else: lines.append('if pcall(hl.gesture, {'+spec+', action='+lua(entry['native'])+'}) then')
        lines.append('  state.input_gesture_live['+lua(key)+'] = '+lua(action)+' end')
    lines+=['state.input_gestures = next_gestures','state.input_layouts = state.input_layouts or {}']
    for name,index in (active_layouts or {}).items():
        command='hyprctl switchxkblayout '+shlex.quote(name)+' '+str(index)
        lines.append('if not __bifrost_verify and state.input_layouts['+lua(name)+'] ~= '+str(index)+' then hl.exec_cmd('+lua(command)+') end')
    lines.append('state.input_layouts = '+lua(active_layouts or {}))
    lines.append('')
    return '\n'.join(lines)


def configured_gestures():
    """Read literal gesture declarations reachable from the user's main config.
    No evaluation/import of Lua; dynamic/custom callbacks remain marked custom.
    This is discovery only, never a runtime dependency on another shell.
    """
    root=Path(os.environ.get('XDG_CONFIG_HOME') or Path.home()/'.config')/'hypr'
    seen=set(); found={}
    def read(path):
        if path in seen or len(seen)>64: return
        seen.add(path)
        try: text=path.read_text()
        except OSError: return
        text=re.sub(r'--[^\n]*','',text)
        for match in re.finditer(r'hl\.gesture\s*\(\s*\{(.*?)\}\s*\)|require\s*\(?\s*["\']([^"\']+)["\']',text,re.S):
            if match.group(2):
                name=match.group(2)
                if re.fullmatch(r'[a-zA-Z0-9_.-]+',name): read(root/(name.replace('.','/')+'.lua'))
                continue
            body=match.group(1)
            fingers=re.search(r'\bfingers\s*=\s*([34])\b',body)
            direction=re.search(r'\bdirection\s*=\s*["\']([a-z]+)["\']',body)
            if not fingers or not direction or re.search(r'\bmods\s*=',body): continue
            action=re.search(r'\baction\s*=\s*["\']([a-z_]+)["\']',body)
            key=fingers.group(1)+':'+direction.group(1)
            found[key]={'action':action.group(1) if action else 'custom','source':str(path),'custom':action is None}
    read(root/'hyprland.lua')
    return found
