"""Exercise deploy/rollback control flow using fake CLIs; never accesses AWS/Docker."""
import os, pathlib, shutil, subprocess, tempfile, unittest

SCRIPT=pathlib.Path(__file__).with_name('deploy-ui.sh')
DIGEST='ghcr.io/techshakti55/technotes-ui@sha256:'+'a'*64

class DeploymentFlow(unittest.TestCase):
    def exercise(self, mode, image=DIGEST):
        with tempfile.TemporaryDirectory() as name:
            root=pathlib.Path(name)
            (root/'scripts').mkdir(); (root/'bin').mkdir()
            shutil.copy(SCRIPT, root/'scripts/deploy-ui.sh')
            (root/'compose.yaml').write_text('name: technotes-production\nservices: {}\n')
            programs={
              'sudo':'#!/bin/sh\n[ "$1" != "-n" ] || shift\nexec "$@"\n',
              'sleep':'#!/bin/sh\nexit 0\n',
              'curl':'#!/bin/sh\n[ "$MODE" != health-failure ]\n',
              'docker':'''#!/bin/sh
echo "$*" >> "$COMMAND_LOG"
case "$1" in
  inspect) echo sha256:oldimage; exit 0;;
  pull) [ "$MODE" != pull-failure ]; exit $?;;
  image) printf '%040d\\n' 1; exit 0;;
  exec) [ "$MODE" != health-failure ]; exit $?;;
  compose)
    case " $* " in
      *" ps "*) echo test-ui-container;;
    esac
    exit 0;;
esac
exit 1
'''}
            for exe,text in programs.items():
                p=root/'bin'/exe; p.write_text(text); p.chmod(0o700)
            env={**os.environ,'PATH':str(root/'bin')+os.pathsep+os.environ['PATH'],
                 'COMMAND_LOG':str(root/'commands'),'MODE':mode}
            result=subprocess.run(['bash',str(root/'scripts/deploy-ui.sh'),image],env=env,capture_output=True,text=True)
            commands=(root/'commands').read_text() if (root/'commands').exists() else ''
            override=(root/'ui.release.yaml').read_text() if (root/'ui.release.yaml').exists() else ''
            return result,commands,override

    def test_success_persists_exact_digest(self):
        result,commands,override=self.exercise('success')
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertIn(DIGEST,override)
        self.assertEqual(commands.count('up -d --no-deps --force-recreate ui'),1)

    def test_pull_failure_never_restarts_ui(self):
        result,commands,override=self.exercise('pull-failure')
        self.assertNotEqual(result.returncode,0)
        self.assertNotIn('up -d',commands)
        self.assertEqual(override,'')

    def test_readiness_failure_restores_previous_image(self):
        result,commands,override=self.exercise('health-failure')
        self.assertNotEqual(result.returncode,0)
        self.assertIn('sha256:oldimage',override)
        self.assertEqual(commands.count('up -d --no-deps --force-recreate ui'),2)

    def test_rejects_untrusted_image_before_docker(self):
        result,commands,override=self.exercise('success','other/image:latest')
        self.assertEqual(result.returncode,2)
        self.assertEqual(commands,'')

if __name__=='__main__': unittest.main()
