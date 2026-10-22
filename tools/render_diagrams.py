#!/usr/bin/env python3
"""Renders docs/diagrams/*.mmd to light and dark PNGs for the README.

Needs Node.js (runs @mermaid-js/mermaid-cli through npx) and an installed
Inter-style font: Adwaita Sans (Inter-based) or Inter. Mermaid sizes boxes
with an installed font, so a web font loaded by CSS would clip labels.
Colors follow the app: mint for what runs on the phone, peach for the cloud.
"""
import json
import pathlib
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / 'docs' / 'diagrams'

THEMES = {
    'light': dict(
        bg='#ffffff', text='#1f2328', line='#6e7781', group_fill='#f6f8fa',
        group_stroke='#d0d7de', phone_fill='#e3f7ee', phone_stroke='#2da77a',
        cloud_fill='#fff0e3', cloud_stroke='#e8833a', io_fill='#ffffff',
        io_stroke='#8c959f', note_fill='#f6f8fa', note_stroke='#d0d7de',
        phone_box='rgba(45,167,122,0.07)', cloud_box='rgba(232,131,58,0.09)',
    ),
    'dark': dict(
        bg='#0d1117', text='#e6edf3', line='#8b949e', group_fill='#161b22',
        group_stroke='#30363d', phone_fill='#0f2e25', phone_stroke='#3fb98a',
        cloud_fill='#33200f', cloud_stroke='#f0883e', io_fill='#0d1117',
        io_stroke='#6e7681', note_fill='#161b22', note_stroke='#30363d',
        phone_box='rgba(63,185,138,0.10)', cloud_box='rgba(240,136,62,0.12)',
    ),
}


def config(t):
    return {
        'theme': 'base',
        'themeVariables': {
            'fontFamily': 'Adwaita Sans, Inter, Liberation Sans, sans-serif',
            'fontSize': '15px',
            'background': t['bg'],
            'textColor': t['text'],
            'primaryColor': t['phone_fill'],
            'primaryBorderColor': t['phone_stroke'],
            'primaryTextColor': t['text'],
            'lineColor': t['line'],
            'clusterBkg': t['group_fill'],
            'clusterBorder': t['group_stroke'],
            'titleColor': t['text'],
            'edgeLabelBackground': t['bg'],
            'actorBkg': t['group_fill'],
            'actorBorder': t['group_stroke'],
            'actorTextColor': t['text'],
            'actorLineColor': t['group_stroke'],
            'signalColor': t['line'],
            'signalTextColor': t['text'],
            'labelBoxBkgColor': t['group_fill'],
            'labelBoxBorderColor': t['group_stroke'],
            'labelTextColor': t['text'],
            'loopTextColor': t['text'],
            'noteBkgColor': t['note_fill'],
            'noteBorderColor': t['note_stroke'],
            'noteTextColor': t['text'],
            'sequenceNumberColor': t['bg'],
            'transitionColor': t['line'],
            'transitionLabelColor': t['text'],
            'stateLabelColor': t['text'],
            'labelBackgroundColor': t['bg'],
        },
        'flowchart': {'curve': 'basis', 'padding': 18, 'nodeSpacing': 40},
        'sequence': {'mirrorActors': False, 'showSequenceNumbers': True},
    }


def main():
    with tempfile.TemporaryDirectory() as tmp:
        tmp = pathlib.Path(tmp)
        for src in sorted(SRC.glob('*.mmd')):
            for name, t in THEMES.items():
                body = src.read_text()
                for key, value in t.items():
                    body = body.replace('{{' + key + '}}', value)
                (tmp / 'in.mmd').write_text(body)
                (tmp / 'cfg.json').write_text(json.dumps(config(t)))
                out = SRC / f'{src.stem}-{name}.png'
                subprocess.run(
                    ['npx', '-y', '-p', '@mermaid-js/mermaid-cli@11', 'mmdc',
                     '-i', tmp / 'in.mmd', '-o', out, '-c', tmp / 'cfg.json',
                     '-b', t['bg'], '-s', '2'],
                    check=True)
                print('wrote', out.relative_to(ROOT))


if __name__ == '__main__':
    main()
