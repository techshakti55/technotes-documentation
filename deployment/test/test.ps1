param([ValidateSet('prepare','start','test','stop','reset','status')][string]$Action='start')
$ErrorActionPreference='Stop'
Set-Location $PSScriptRoot
function Run-TestCommand { param([string]$Exe,[string[]]$Arguments)
  & $Exe @Arguments
  if($LASTEXITCODE -ne 0){throw "$Exe failed; production has not been touched."}
}
switch($Action){
  'prepare' { Run-TestCommand python @('prepare.py') }
  'start' {
    Run-TestCommand python @('prepare.py')
    Run-TestCommand docker @('compose','build')
    Run-TestCommand docker @('compose','up','-d')
    Run-TestCommand python @('wait.py')
    Write-Host 'TEST UI: http://localhost:25173 - production is separate.'
  }
  'test' {
    Run-TestCommand npm.cmd @('ci')
    Run-TestCommand npx.cmd @('playwright','install','chromium')
    Run-TestCommand npm.cmd @('test')
  }
  'stop' { Run-TestCommand docker @('compose','stop') }
  'reset' {
    if((Read-Host 'Deletes ONLY technotes-test database volumes. Type RESET TEST') -ne 'RESET TEST'){return}
    Run-TestCommand docker @('compose','down','--volumes')
  }
  'status' { Run-TestCommand docker @('compose','ps','-a') }
}
