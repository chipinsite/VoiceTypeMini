"""Exercise the wrapper with isolated command stubs; never download model weights."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'prefetch-whisperkit-models.sh'


class PrefetchWrapperTests(unittest.TestCase):
    def run_wrapper(self, arguments, fail_download=False):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        commands = root / 'bin'
        commands.mkdir()
        log = root / 'curl.jsonl'
        swift = commands / 'swift'
        swift.write_text('''#!/usr/bin/env python3
import pathlib,sys
args=sys.argv[3:]
output=None
models=[]
i=0
while i<len(args):
    if args[i]=='--output':
        i+=1
        output=pathlib.Path(args[i])
    elif args[i] not in ['--local-only','--load']:
        models.append(args[i])
    i+=1
for model in models or ['base']:
    folder=output/('openai_whisper-'+model.removeprefix('openai_whisper-'))
    folder.mkdir(parents=True,exist_ok=True)
    (folder/'tokenizer.json').write_text('existing tokenizer')
''')
        curl = commands / 'curl'
        curl.write_text('''#!/usr/bin/env python3
import json,os,pathlib,sys
with open(os.environ['PREFETCH_TEST_LOG'],'a') as log:
    log.write(json.dumps(sys.argv[1:])+'\\n')
output=pathlib.Path(sys.argv[sys.argv.index('-o')+1])
output.write_text('partial' if os.environ['PREFETCH_TEST_FAIL']=='1' else 'downloaded tokenizer')
sys.exit(int(os.environ['PREFETCH_TEST_FAIL']))
''')
        swift.chmod(0o755)
        curl.chmod(0o755)
        default = root / 'default models'
        custom = root / 'custom models'
        args = [str(custom) if a == '{custom}' else a for a in arguments]
        environment = dict(os.environ, PATH=f'{commands}:{os.environ["PATH"]}',
                           VOICE_TYPE_WHISPERKIT_MODELS_DIR=str(default),
                           PREFETCH_TEST_LOG=str(log), PREFETCH_TEST_FAIL=str(int(fail_download)))
        result = subprocess.run(['/bin/bash', str(SCRIPT), *args], env=environment,
                                capture_output=True, text=True)
        calls = [json.loads(line) for line in log.read_text().splitlines()] if log.exists() else []
        return result, default, custom, calls

    def test_default_downloads_base_tokenizers(self):
        result, default, _, calls = self.run_wrapper([])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(calls), 3)
        self.assertEqual((default/'openai_whisper-base/tokenizer.json').read_text(), 'downloaded tokenizer')

    def test_local_only_never_invokes_curl(self):
        result, _, custom, calls = self.run_wrapper(['--local-only', '--load', '--output', '{custom}', 'base'])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls, [])
        self.assertEqual((custom/'openai_whisper-base/tokenizer.json').read_text(), 'existing tokenizer')

    def test_custom_output_receives_tokenizers(self):
        result, default, custom, calls = self.run_wrapper(['--output', '{custom}', 'base'])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(default.exists())
        self.assertEqual((custom/'openai_whisper-base/tokenizer.json').read_text(), 'downloaded tokenizer')
        self.assertEqual(len(calls), 3)

    def test_coreml_variant_uses_canonical_repository(self):
        result, _, _, calls = self.run_wrapper(['large-v3-v20240930_626MB'])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(all(any('/openai/whisper-large-v3/resolve/' in arg for arg in call) for call in calls))

    def test_failed_download_preserves_existing_tokenizer(self):
        result, default, _, calls = self.run_wrapper(['base'], fail_download=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(calls), 1)
        self.assertEqual((default/'openai_whisper-base/tokenizer.json').read_text(), 'existing tokenizer')
        self.assertEqual(list(default.rglob('.tokenizer.*')), [])


if __name__ == '__main__':
    unittest.main()
