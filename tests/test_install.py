"""Run the installer against isolated files and mocked system/install commands."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
DRIVER = r'''
import json, os
from pathlib import Path
import sys
base = Path(sys.argv[0]).resolve().parent.parent
name = Path(sys.argv[0]).name
args = sys.argv[1:]
with (base / 'calls.jsonl').open('a') as log:
    log.write(json.dumps([name] + args) + '\n')
scenario = os.environ.get('AUDIT_SCENARIO', '')
home = base / 'user home'
if name == 'uname':
    print('Darwin' if args == ['-s'] else ('x86_64' if scenario == 'wrong-arch' else 'arm64'))
elif name == 'sw_vers':
    print('15.7' if scenario == 'older' else '26.0')
elif name == 'curl':
    url = args[-1]
    if scenario == 'download-failure': sys.exit(22)
    output = Path(args[args.index('-o') + 1])
    if 'Homebrew' in url:
        if scenario == 'installer-failure':
            output.write_text('exit 9\n')
        else:
            output.write_text('"' + str(base / 'bin/mocktool') + '" install-brew\n')
    elif 'ohmyzsh' in url:
        output.write_text('"' + str(base / 'bin/mocktool') + '" install-omz\n')
    else:
        output.write_text('"' + str(base / 'bin/mocktool') + '" install-rust\n')
elif name == 'mocktool':
    if args == ['install-brew']:
        folder = base / 'prefix/bin'
        folder.mkdir(parents=True, exist_ok=True)
        (folder / 'brew').symlink_to(base / 'bin/brew')
    elif args == ['install-omz']:
        folder = home / '.oh-my-zsh/themes'
        folder.mkdir(parents=True)
        (folder / 'robbyrussell.zsh-theme').write_text('PROMPT="arrow "\n')
        (home / '.zshrc').write_text('export ZSH="' + str(home / '.oh-my-zsh') + '"\nZSH_THEME="robbyrussell"\n')
    elif args == ['install-rust']:
        folder = home / '.cargo/bin'
        folder.mkdir(parents=True)
        (folder / 'rustup').write_text('#!/bin/sh\nexit 0\n')
        (folder / 'rustup').chmod(0o755)
elif name == 'brew':
    if args == ['shellenv']:
        if scenario == 'shellenv-failure': sys.exit(8)
        print(':')
    elif scenario == 'package-failure': sys.exit(7)
elif name == 'arch':
    sys.exit(0 if scenario == 'rosetta-present' else 1)
elif name == 'ssh-keygen':
    dest = Path(args[args.index('-f') + 1])
    if '-y' in args:
        print('ssh-ed25519 MOCK')
    else:
        dest.write_text('mock private key')
        Path(str(dest) + '.pub').write_text('ssh-ed25519 MOCK\n')
elif name == 'ssh-agent':
    print('export SSH_AUTH_SOCK=/mock/agent')
elif name == 'pbcopy':
    (base / 'clipboard').write_text(sys.stdin.read())
elif name in ['sudo', 'git', 'defaults', 'killall', 'ssh-add']:
    pass
else:
    raise SystemExit('Unexpected mocked command: ' + name)
'''


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='macbuttler-test-')
        self.base = Path(self.temp.name)
        self.home = self.base / 'user home'
        self.home.mkdir()
        self.bin = self.base / 'bin'
        self.bin.mkdir()
        names = ['mocktool', 'uname', 'sw_vers', 'curl', 'brew', 'arch',
                 'ssh-keygen', 'ssh-agent', 'ssh-add', 'pbcopy', 'sudo',
                 'git', 'defaults', 'killall']
        for name in names:
            path = self.bin / name
            path.write_text('#!' + sys.executable + '\n' + DRIVER)
            path.chmod(0o755)
        self.source = self.base / 'source'
        self.source.mkdir()
        for name in ['.vimrc', 'halloy', 'wog']:
            src = REPO / name
            if src.is_dir(): shutil.copytree(src, self.source / name)
            else: shutil.copy2(src, self.source / name)
        # Redirect user paths and the explicitly selected system executables.
        # The real HOME environment variable is never changed.
        source = (REPO / 'install.sh').read_text().replace('$HOME', str(self.home))
        source = source.replace('/opt/homebrew/bin/brew', str(self.base / 'prefix/bin/brew'))
        for name in ['arch', 'ssh-keygen', 'ssh-agent', 'ssh-add']:
            source = source.replace('/usr/bin/' + name, str(self.bin / name))
        self.script = self.source / 'install.sh'
        self.script.write_text(source)
        self.addCleanup(self.temp.cleanup)

    def execute(self, scenario='', skip_apps=False):
        env = dict(os.environ)
        for key in ['ZSH', 'ZDOTDIR', 'ZSH_CUSTOM', 'CARGO_HOME', 'SSH_AUTH_SOCK', 'SKIP_APPS']:
            env.pop(key, None)
        env.update(PATH=str(self.bin) + ':/usr/bin:/bin:/usr/sbin:/sbin', AUDIT_SCENARIO=scenario)
        if skip_apps: env['SKIP_APPS'] = '1'
        return subprocess.run(['/bin/zsh', '-f', str(self.script), 'test@example.com', 'Test User'],
                              env=env, capture_output=True, text=True, timeout=30)

    def calls(self):
        path = self.base / 'calls.jsonl'
        return [json.loads(line) for line in path.read_text().splitlines()]

    def assert_success(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('Setup finished.', result.stdout)

    def test_fresh_install_and_rerun(self):
        self.assert_success(self.execute())
        calls = self.calls()
        self.assertIn(['sudo', 'softwareupdate', '--install-rosetta', '--agree-to-license'], calls)
        self.assertIn(['brew', 'install', 'container'], calls)
        rerun = self.execute()
        self.assert_success(rerun)
        self.assertIn('World of Goo 2 data', rerun.stdout)
        self.assertEqual(len([c for c in self.calls() if c[0] == 'curl']), 3)
        self.assertEqual((self.home / '.zprofile').read_text().count('# Homebrew'), 1)
        self.assertEqual((self.home / '.zshrc').read_text().count('ZSH_THEME="macbuttler"'), 1)
        self.assertEqual((self.home / '.ssh/config').read_text().count('Host github.com'), 1)
        self.assertEqual((self.base / 'clipboard').read_text(), 'ssh-ed25519 MOCK\n')
        # The generated theme is valid Zsh and prefixes the upstream prompt once.
        theme = self.home / '.oh-my-zsh/custom/themes/macbuttler.zsh-theme'
        result = subprocess.run(['/bin/zsh', '-f', '-c', 'ZSH=$1; source "$2"; print -r -- "$PROMPT"',
                                 'test', str(self.home / '.oh-my-zsh'), str(theme)],
                                capture_output=True, text=True, check=True)
        self.assertEqual(result.stdout.strip(), '%n@%m arrow')

    def test_older_macos_skips_only_container(self):
        result = self.execute('older')
        self.assert_success(result)
        self.assertIn('container requires macOS 26', result.stdout)
        self.assertNotIn(['brew', 'install', 'container'], self.calls())
        self.assertIn(['brew', 'install', 'python3', 'swiftly'], self.calls())

    def test_skip_apps_does_not_install_rosetta(self):
        self.assert_success(self.execute(skip_apps=True))
        installs = [c for c in self.calls() if c[0] == 'brew' and c[1] == 'install']
        self.assertEqual(installs, [['brew', 'install', '--cask', 'halloy']])
        self.assertFalse(any('--install-rosetta' in c for c in self.calls()))

    def test_existing_rosetta_is_reused(self):
        self.assert_success(self.execute('rosetta-present'))
        self.assertFalse(any('--install-rosetta' in c for c in self.calls()))

    def test_failures_stop_before_later_steps(self):
        for scenario, code in [('download-failure', 22), ('installer-failure', 9),
                               ('shellenv-failure', 8), ('package-failure', 7)]:
            with self.subTest(scenario=scenario):
                result = self.execute(scenario)
                self.assertEqual(result.returncode, code, result.stdout + result.stderr)
                self.assertNotIn('Setup finished.', result.stdout)
                self.assertIn('Command failed:', result.stderr)
                self.assertIn('Setup stopped during:', result.stderr)
                self.assertFalse(any(c[0] == 'defaults' for c in self.calls()))

    def test_existing_game_and_configuration_are_backed_up(self):
        game = self.home / 'Library/Containers/com.2dboy.worldofgoo2mac/Data/Library/Application Support/WorldOfGoo2'
        game.mkdir(parents=True)
        (game / 'wog2_1.dat').write_text('previous game data')
        (self.home / '.vimrc').write_text('previous vim config')
        self.assert_success(self.execute())
        self.assertEqual((game / 'wog2_1.dat').read_bytes(), (REPO / 'wog/wog2_1.dat').read_bytes())
        backups = list(game.glob('wog2_1.dat.macbuttler-backup-*'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), 'previous game data')
        self.assertEqual(len(list(self.home.glob('.vimrc.macbuttler-backup-*'))), 1)

    def test_wrong_architecture_stops_before_sudo(self):
        result = self.execute('wrong-arch')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any(c[0] == 'sudo' for c in self.calls()))


if __name__ == '__main__':
    unittest.main()
