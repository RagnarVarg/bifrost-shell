#!/usr/bin/env python3
"""Physical brightness discovery/read/write for the single QML Brightness service."""
import concurrent.futures
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys


def run(args, timeout=6):
    try:
        result = subprocess.run(args, capture_output=True, text=True, timeout=timeout,
                                env=dict(os.environ, LC_ALL='C'))
        return result.returncode, result.stdout + ("\n" + result.stderr if result.returncode else "")
    except subprocess.TimeoutExpired as error:
        output = error.stdout or b''
        if isinstance(output, bytes):
            output = output.decode(errors='replace')
        return 124, output + '\nDisplay detection timed out'
    except OSError as error:
        return 1, str(error)


def vcp(text):
    m = re.search(r'VCP 10 C (\d+) (\d+)', text)
    if not m or int(m[2]) <= 0 or int(m[1]) > int(m[2]):
        raise ValueError('Display does not report usable brightness')
    return int(m[1]), int(m[2])


def ddc_devices(text):
    result = []
    for block in re.split(r'(?m)^\s*(?:Display \d+|Invalid display)\s*$', text)[1:]:
        bus = re.search(r'I2C bus:\s*/dev/i2c-(\d+)', block)
        name = re.search(r'Monitor:\s*(.+)', block)
        if bus:
            result.append({'id': 'ddc:' + bus[1], 'name': name[1].strip() if name else 'I2C ' + bus[1]})
    return result


def read_ddc(device, errors=None):
    code, text = run(['ddcutil', '--bus', device['id'].split(':')[1], 'getvcp', '10', '--brief'])
    if code:
        if errors is not None:
            errors.append(device['name'] + ": " + (text.strip() or "Brightness read failed"))
        return None
    try:
        value, maximum = vcp(text)
        return dict(device, value=value / maximum, maximum=maximum, provider='ddc')
    except ValueError as error:
        if errors is not None:
            errors.append(device['name'] + ": " + str(error))
        return None


def discover(errors=None, unavailable=None):
    devices = []
    for path in Path('/sys/class/backlight').glob('*'):
        try:
            maximum = int((path / 'max_brightness').read_text())
            value = int((path / 'brightness').read_text())
            if maximum > 0:
                devices.append(dict(id='backlight:' + path.name, name=path.name,
                                    value=value / maximum, maximum=maximum, provider='backlight'))
        except (OSError, ValueError):
            continue
    code, text = run(['ddcutil', 'detect', '--brief'], timeout=20)
    if code and errors is not None:
        errors.append(text.strip() or "Display detection failed")
    # A bad second monitor can make detect fail while valid displays remain.
    if text:
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            candidates = ddc_devices(text)[:16]
            results = list(pool.map(read_ddc if errors is None else lambda d: read_ddc(d, errors), candidates))
            devices += [d for d in results if d]
            if unavailable is not None:
                unavailable.extend(d for d, result in zip(candidates, results) if result is None)
    return devices


def set_value(device, fraction):
    if not math.isfinite(fraction):
        raise ValueError('Invalid brightness')
    fraction = min(1, max(0.01, fraction))
    if re.fullmatch(r'backlight:[a-zA-Z0-9_.-]+', device):
        args = ['brightnessctl', '-d', device.split(':')[1], 'set', str(round(fraction * 100)) + '%']
    elif re.fullmatch(r'ddc:\d+', device):
        bus = device.split(':')[1]
        code, text = run(['ddcutil', '--bus', bus, 'getvcp', '10', '--brief'])
        if code:
            raise ValueError('Display unavailable')
        _, maximum = vcp(text)
        args = ['ddcutil', '--bus', bus, 'setvcp', '10', str(round(fraction * maximum))]
    else:
        raise ValueError('Invalid display id')
    if run(args)[0]:
        raise ValueError('Brightness write failed')


if __name__ == '__main__':
    try:
        if len(sys.argv) == 4 and sys.argv[1] == 'set':
            set_value(sys.argv[2], float(sys.argv[3]))
            print(json.dumps({'ok': True}))
        elif sys.argv[1:] == ['list']:
            errors = []
            unavailable = []
            displays = discover(errors, unavailable)
            print(json.dumps({'displays': displays, 'unavailable': unavailable, 'error': '\n'.join(errors)}))
        else:
            raise ValueError('Expected list or set DISPLAY FRACTION')
    except (ValueError, OSError) as error:
        print(json.dumps({'error': str(error)}))
        sys.exit(1)
