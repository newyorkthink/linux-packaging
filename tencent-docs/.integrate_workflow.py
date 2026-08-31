#!/usr/bin/env python3
import re
import shlex
from pathlib import Path

WORKFLOW = Path('.github/workflows/build.yml')
TEMP_WORKFLOW = Path('.github/workflows/test_tencent_docs.yml')
SELF = Path('tencent-docs/.integrate_workflow.py')
README = Path('tencent-docs/README.md')

text = WORKFLOW.read_text(encoding='utf-8')


def insert_before(marker: str, addition: str) -> None:
    global text
    if addition in text:
        return
    if text.count(marker) != 1:
        raise SystemExit(f'cannot uniquely locate workflow marker: {marker!r}')
    text = text.replace(marker, addition + marker, 1)


insert_before(
    "      - '.github/workflows/build.yml'\n",
    "      - 'tencent-docs/**'\n",
)
insert_before(
    "\npermissions:\n",
    "          - tencent-docs/build_tencent-docs.sh\n",
)

lines = text.splitlines(keepends=True)
array_tokens = {
    'KEYS': 'tencent_docs',
    'SCRIPTS': "'tencent-docs/build_tencent-docs.sh'",
    'DIRS': 'tencent-docs',
}
for array_name, token in array_tokens.items():
    matches = [i for i, line in enumerate(lines) if line.lstrip().startswith(f'{array_name}=(')]
    if len(matches) != 1:
        raise SystemExit(f'cannot uniquely locate {array_name}')
    index = matches[0]
    if token in lines[index]:
        continue
    stripped = lines[index].rstrip('\n')
    if not stripped.endswith(')'):
        raise SystemExit(f'invalid {array_name} array format')
    lines[index] = stripped[:-1] + f' {token})\n'
text = ''.join(lines)

job = """
  build_tencent_docs:
    name: Build Tencent Docs
    needs: plan
    if: fromJSON(needs.plan.outputs.builds).tencent_docs == 'true'
    runs-on: *arch_runner
    container: *arch_container
    permissions: *arch_permissions
    env:
      BUILD_SCRIPT: tencent-docs/build_tencent-docs.sh
      ARTIFACT_DIR: tencent-docs/dist
      RELEASE_NAME: tencent-docs.AppImage
      RUN_FROM_ROOT: "0"
    steps: *arch_steps
"""
if '\n  build_tencent_docs:\n' not in text:
    text = text.rstrip() + '\n\n' + job

# Validate the plan mapping before writing anything.
def parse_array(source: str, name: str):
    match = re.search(rf'^\s*{name}=\((.*)\)$', source, re.MULTILINE)
    if not match:
        raise SystemExit(f'missing {name} array')
    return shlex.split(match.group(1))

keys = parse_array(text, 'KEYS')
scripts = parse_array(text, 'SCRIPTS')
dirs = parse_array(text, 'DIRS')
if not (len(keys) == len(scripts) == len(dirs)):
    raise SystemExit('KEYS/SCRIPTS/DIRS length mismatch')
mapping = dict(zip(keys, zip(scripts, dirs)))
if mapping.get('tencent_docs') != ('tencent-docs/build_tencent-docs.sh', 'tencent-docs'):
    raise SystemExit(f'bad Tencent Docs plan mapping: {mapping.get("tencent_docs")}')

checks = {
    "      - 'tencent-docs/**'\n": 'push path',
    '          - tencent-docs/build_tencent-docs.sh\n': 'workflow_dispatch option',
    '\n  build_tencent_docs:\n': 'build job',
    '      BUILD_SCRIPT: tencent-docs/build_tencent-docs.sh\n': 'job build script',
    '      ARTIFACT_DIR: tencent-docs/dist\n': 'job artifact dir',
    '      RELEASE_NAME: tencent-docs.AppImage\n': 'job release name',
}
for needle, label in checks.items():
    if text.count(needle) != 1:
        raise SystemExit(f'invalid Tencent Docs {label} count')

WORKFLOW.write_text(text, encoding='utf-8')
README.write_text(
    "# Tencent Docs\n\n"
    "将腾讯文档官方 Linux Debian 包封装为 AppImage。\n\n"
    "- 上游包：`https://docs.qq.com/api/package/get?channel_id=30001&version_id=latest&package_name=TencentDocs-x64.deb`\n"
    "- 保留官方 `/opt/腾讯文档` Electron 运行时及 resources（含 app.asar 和原生模块）\n"
    "- 不替换上游 Electron，不修改 app.asar\n"
    "- 仅补齐 AppImage 运行时依赖和入口\n"
    "- 产物：`tencent-docs.AppImage`\n"
    "- 统一构建入口：`.github/workflows/build.yml`\n",
    encoding='utf-8',
)
TEMP_WORKFLOW.unlink(missing_ok=True)
SELF.unlink(missing_ok=True)
