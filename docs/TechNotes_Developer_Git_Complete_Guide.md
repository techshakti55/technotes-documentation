# TechNotes — Developer Git Guide

**Clone → सभी branches देखें → अपनी branch बनाएं → काम करें → test → commit → push → PR → review → merge के बाद sync**

तारीख: 17 October 2026 | Windows PowerShell | GitHub owner: techshakti55

यह guide नए developer को सीधे भेज सकते हैं। पहले सही section पढ़ें, फिर commands एक block करके चलाएं। कोई command fail हो तो आगे के dependent steps रोककर error ठीक करें। किसी repository का code इस guide को बनाने के लिए बदला नहीं गया है।

## 1. सबसे पहले: repositories और branches का फर्क

हर project repository को **एक बार** clone करना है। सामान्य `git clone` उस repository की सभी advertised branches के remote-tracking references लेता है, लेकिन केवल एक branch checkout करता है। `git branch` में केवल main दिखना सामान्य है; बाकी के लिए `git branch -r` या `git branch -a` देखें।

- Repository = पूरा project और उसकी Git history.
- Local branch = आपके laptop की branch, जैसे develop.
- origin/develop = आखिरी fetch के समय GitHub develop का local reference.
- Working branch = आपके task की branch, जैसे feature/rahul-note-validation.
- सात repositories के लिए सात folders चाहिए; हर branch के लिए अलग clone जरूरी नहीं।

`--single-branch`, shallow clone या Download ZIP इस workflow के लिए न चुनें। ZIP में Git history/remotes नहीं आते। पहले से ऐसा clone किया है तो section 6 देखें।

## 2. Git और account की तैयारी

PowerShell खोलें:

```powershell
git --version
```

यदि git recognized नहीं है: [Git for Windows](https://git-scm.com/downloads/win) install करें, terminal/IDE दोबारा खोलें। Developer अपने GitHub account से sign in करे। Shakti private repository access और working branches push करने के लिए collaborator/team permission दे; invitation उसी account से accept करें। Public repository clone होना push permission का प्रमाण नहीं है।

एक बार अपनी commit identity set करें। नीचे की example values को **अपनी असली values** से बदलें:

```powershell
git config --global user.name "Your Full Name"
git config --global user.email "your-github-verified-email@example.com"
git config --global --get user.name
git config --global --get user.email
```

Privacy चाहिए तो अपने GitHub Settings → Emails में दिया exact noreply email इस्तेमाल करें। Global config आपके दूसरे repositories पर भी लागू होती है; किसी एक repository के लिए override चाहिए तो उसके अंदर --global हटाकर set करें। यह identity commit author है; GitHub login बदलने की command नहीं है।

HTTPS clone पर Git Credential Manager browser sign-in दे तो अपने account से complete करें। GitHub account password को Git password की तरह न दें। Organization policy के कारण PAT जरूरी हो तो appropriate repository access वाला token privately configure करें; URL, document या screenshot में token न रखें।

## 3. सभी सात repositories clone करें — first time only

यदि D: drive नहीं है तो नीचे D:\TechNotes की जगह अपना path चुनें, जैसे C:\TechNotes। Existing clone होने पर दोबारा clone न करें; section 5/6 पर जाएं।

```powershell
New-Item -ItemType Directory -Force D:\TechNotes | Out-Null
Set-Location D:\TechNotes
git clone https://github.com/techshakti55/technotes-documentation.git
git clone https://github.com/techshakti55/technotes-ui.git
git clone https://github.com/techshakti55/technotes-user-oauth-service.git
git clone https://github.com/techshakti55/technotes-notes-service.git
git clone https://github.com/techshakti55/technotes-api-gateway.git
git clone https://github.com/techshakti55/technotes-eureka-server.git
git clone https://github.com/techshakti55/technotes-config-server.git
```

हर clone की सफलता अलग जांचें। Clone commands independent हैं; कोई एक fail हुआ हो तो उसकी समस्या ठीक करके केवल वही command दोहराएं। Existing folder को delete करके retry न करें।

| Folder / GitHub repository | काम |
| --- | --- |
| [technotes-documentation](https://github.com/techshakti55/technotes-documentation) | Scope, architecture, API contracts, process |
| [technotes-ui](https://github.com/techshakti55/technotes-ui) | React/Vite UI |
| [technotes-user-oauth-service](https://github.com/techshakti55/technotes-user-oauth-service) | Login, OAuth/OIDC, user profile |
| [technotes-notes-service](https://github.com/techshakti55/technotes-notes-service) | Notes, categories, publish workflow |
| [technotes-api-gateway](https://github.com/techshakti55/technotes-api-gateway) | API routing and CORS |
| [technotes-eureka-server](https://github.com/techshakti55/technotes-eureka-server) | Discovery |
| [technotes-config-server](https://github.com/techshakti55/technotes-config-server) | Configuration platform |

## 4. Clone issue: error के अनुसार समाधान

Exact error अभी उपलब्ध नहीं है; इसलिए नीचे common cases दिए हैं। ये diagnosis के विकल्प हैं, developer के issue का confirmed कारण नहीं।

| Error / स्थिति | क्या जांचें / करें |
| --- | --- |
| Repository not found / 404 | URL spelling सही करें; browser में उसी account से repo खोलें; private repo invitation/permission जांचें। |
| Authentication failed / 401 | Browser/Git credential account जांचें; GitHub password की जगह Credential Manager sign-in या approved token authentication उपयोग करें। |
| Permission denied (publickey) | SSH authentication fail है। इस guide के HTTPS clone URL से नया clone करें; existing clone का remote बदलने का उदाहरण नीचे है। |
| 403 / permission denied while pushing | Clone permission और push permission अलग हैं। सही account और collaborator/team write permission जांचें। Branch protection पर working branch push और PR करें। |
| destination path already exists and is not an empty directory | अंदर जाकर git status देखें। Valid clone है तो fetch करें। Non-Git folder हो तो उसे सुरक्षित रखें और नया अलग folder name लें। |
| not a git repository | सही repository folder में cd करें। D:\TechNotes parent folder खुद Git repository नहीं है। |
| Could not resolve host / timed out / proxy error | Internet, github.com connectivity और organization proxy जांचें। SSL verification बंद न करें। |
| SSL certificate problem | Computer clock, trusted certificates और company proxy/certificate setup ठीक कराएं। `http.sslVerify=false` न लगाएं। |
| RPC failed / early EOF / interrupted clone | Stable network/free space जांचें; existing partial folder को सुरक्षित रखते हुए अलग target folder में retry करें। इसे default तौर पर shallow clone बनाकर न छिपाएं। |
| Remote branch develop not found | git ls-remote से actual branch names जांचें; correct repo/base lead से लें। main से नकली develop बनाकर missing branch न छिपाएं। |

Connection check, clone से पहले भी चल सकता है:

```powershell
git ls-remote --heads https://github.com/techshakti55/technotes-notes-service.git
```

Expected: SHA और refs/heads/main, refs/heads/develop जैसे actual branch names। यह source clone नहीं करता और push access verify नहीं करता।

Existing clone में SSH से HTTPS बदलना हो तो पहले remote देखें, और **उसी repository का** URL लगाएं:

```powershell
Set-Location D:\TechNotes\technotes-notes-service
git remote -v
git remote set-url origin https://github.com/techshakti55/technotes-notes-service.git
git fetch origin
```

Wrong cached account मिले तो Windows Credential Manager/Git Credential Manager में उस GitHub credential की पहचान करके सही account से reauthenticate करें। सभी credentials bulk-delete न करें।

## 5. हर repository में सभी branches देखें

Notes उदाहरण है। यही block हर required repository के अपने folder में चलाएं:

```powershell
Set-Location D:\TechNotes\technotes-notes-service
git remote -v
git status --short --branch
git fetch --prune origin
git branch
git branch -r
git branch -a
git branch -vv
```

| Command | अर्थ |
| --- | --- |
| git remote -v | किस GitHub repository से connected हैं |
| git status --short --branch | Current branch और changed/untracked files |
| git fetch --prune origin | Remote branch references अपडेट; GitHub से हट चुकी branches के stale remote references हटते हैं; local branches/work नहीं मिटते |
| git branch | Local branches; current branch के आगे * |
| git branch -r | Remote-tracking branches |
| git branch -a | Local और remote दोनों |
| git branch -vv | Local branch upstream और last fetched ahead/behind स्थिति |

Fetch working files में merge नहीं करता। `git fetch --all` सभी configured remotes fetch करता है; हर branch को working folder में checkout या हर local branch को update नहीं करता।

## 6. केवल main दिखती है / single-branch clone हो गया

पहले देखें:

```powershell
git config --get-all remote.origin.fetch
git ls-remote --heads origin
git branch -r
```

यदि GitHub पर बाकी branches हैं लेकिन fetch mapping केवल main तक limited है, इस normal developer clone में सभी branches tracking enable करें:

```powershell
git remote set-branches origin '*'
git fetch --prune origin
git branch -r
```

अब existing remote branch को local tracking branch बनाएं, **केवल जब local develop मौजूद नहीं हो**:

```powershell
git switch --track origin/develop
```

Local develop पहले से मौजूद है तो केवल `git switch develop` करें। Origin/main को local main बनाना हो और main local नहीं हो तो यही pattern `git switch --track origin/main` है। हर remote feature branch की local copy बनाना जरूरी नहीं; जरूरत पर switch करें।

यदि shallow clone हुआ है, जांचें:

```powershell
git rev-parse --is-shallow-repository
```

केवल true आने पर full available history लेने के लिए:

```powershell
git fetch --unshallow origin
```

ZIP folder हो तो उसे Git clone मानकर git init न करें। Actual repository अलग folder में clone करें, फिर जरूरत की local edits review करके copy करें।

## 7. Main और develop latest करना

पहले `git status` से worktree clean होना सुनिश्चित करें। Modified/untracked work होने पर section 12 की preservation instructions पढ़ें।

Local develop मौजूद है:

```powershell
git fetch origin
git switch develop
git pull --ff-only origin develop
git status --short --branch
git log -1 --oneline
```

Local develop absent हो तो fetch के बाद `git switch --track origin/develop`, फिर ऊपर pull/status करें। Local main को भी latest देखना हो और वह मौजूद है:

```powershell
git switch main
git pull --ff-only origin main
git switch develop
```

Branch latest होना यह नहीं बताता कि main और develop में code एक जैसा है। Develop में next release के reviewed changes हो सकते हैं। `--ff-only` diverged history पर रुकता है; इसे automatic reset/force से ठीक न करें।

## 8. अपना नया task और working branch

एक वास्तविक assigned task चुनें। नीचे sample branch में devname को अपने नाम और note-validation को actual task से बदलें। Jira key हो तभी शामिल करें। हर नए task के लिए latest develop से नई branch बनाएं।

```powershell
Set-Location D:\TechNotes\technotes-notes-service
git status
git fetch origin
git switch develop
git pull --ff-only origin develop
git switch -c feature/devname-note-validation
git branch --show-current
git status --short --branch
```

Expected current branch: feature/devname-note-validation. इसी पर IntelliJ/VS Code से changes करें। `git switch -c` नई local branch बनाकर उस पर switch करता है; अभी GitHub पर branch नहीं बनी है। First push पर बनेगी।

Branch पहले से local हो तो दोबारा -c न करें:

```powershell
git switch feature/devname-note-validation
```

दूसरे computer से अपनी पहले pushed branch continue करनी हो और local absent हो:

```powershell
git fetch origin
git switch --track origin/feature/devname-note-validation
```

एक task UI और Notes दोनों बदलता है तो दोनों repositories में branch और अलग PR बनेंगे। एक repo में branch बनाने से बाकी repos की branches नहीं बनतीं। main/develop पर direct development न करें।

## 9. काम करते समय inspect और test

```powershell
git branch --show-current
git status
git diff --stat
git diff
```

Backend में relevant tests current repo/configuration के अनुसार चलाएं; Maven Wrapper वाले repo में:

```powershell
.\mvnw.cmd test
```

UI repo में install prerequisites पूरे होने के बाद:

```powershell
npm run build
```

Gateway में documented configuration/launcher हो तो उसके README के अनुसार test करें। Build fail हुआ हो तो PR description में pass न लिखें। Tests के लिए databases/env जरूरी हो सकते हैं; Git clone उन्हें setup/start नहीं करता।

## 10. काम पूरा: stage → commit → push

पहले modified files देखें। नीचे src/main/java staging उदाहरण है, हर repo में मौजूद होना जरूरी नहीं। Actual intended file paths चुनें; UI changes के लिए relevant UI paths लें।

```powershell
git status
git diff
git add src/main/java
# Tests भी बदले हों और path मौजूद हो तो:
git add src/test
git diff --staged
git status
git commit -m "feat: improve note validation"
git log -1 --oneline
git push -u origin feature/devname-note-validation
```

यदि केवल एक file बदली हो तो `git add` में उसका exact path दें। Blanket `git add .` से पहले सभी changes/untracked files inspect करें। Credentials, private keys, .env और generated build output stage न हों। Stage में कुछ नहीं है तो commit की जरूरत नहीं।

- add = अगले commit के लिए चुनना; upload नहीं।
- commit = laptop पर snapshot; GitHub upload नहीं।
- push = GitHub पर branch/commits भेजना।
- -u = branch का upstream set करना; बाद के pushes पर `git push` पर्याप्त।

Review corrections के लिए उसी branch में edit/test करें, intended files stage करें, नया commit और `git push` करें। Existing PR अपने-आप update होगी; नया PR जरूरी नहीं।

## 11. Pull Request — browser पर

Repository के GitHub page पर Pull requests → New pull request खोलें:

- Base: develop
- Compare: feature/devname-note-validation
- Title: actual change का संक्षिप्त नाम; real ticket हो तो उसका key जोड़ें।
- Description: problem/result, files/behavior changed, tests और परिणाम, configuration/contract impact, related cross-repository PRs.
- Reviewer: Shakti/assigned teammate. PR URL share करें और वास्तविक task status update करें।

उदाहरण PR page: https://github.com/techshakti55/technotes-notes-service/pulls

`git pull` और Pull Request अलग हैं। Push करने से code develop में merge नहीं होता। Lead/team review और required checks के बाद merge करेगी। main release merge lead coordinate करेगा।

## 12. अगले दिन और बीच में develop update

अपनी existing task branch पर काम जारी हो तो नई branch रोज न बनाएं। पहले current state देखें:

```powershell
Set-Location D:\TechNotes\technotes-notes-service
git status
git branch --show-current
git fetch origin
```

अपनी branch का upstream already set हो, worktree clean हो और remote task branch से sync चाहिए:

```powershell
git switch feature/devname-note-validation
git pull --ff-only
```

Latest develop को अपनी task branch में integrate करना हो तो clean worktree पर, team workflow के अनुसार merge करें। नीचे merge-based तरीका shared history rewrite नहीं करता:

```powershell
git switch feature/devname-note-validation
git fetch origin
git merge origin/develop
```

Merge successful हो तो relevant tests, review, जरूरत हो तो `git push` करें। इससे local develop branch update नहीं होती; changes सीधे feature branch में integrate होते हैं। Rebase/force push इस beginner workflow में जरूरी नहीं।

### Unsaved / uncommitted work सुरक्षित रखें

पहला विकल्प: अपने task branch पर reviewed WIP commit बनाएं। Temporarily branch switch करना जरूरी हो तो stash उपयोग कर सकते हैं:

```powershell
git stash push -u -m "WIP before branch switch"
git stash list
```

`-u` untracked files भी stash करता है, ignored files नहीं। Files में credentials हों तो stash भी local Git storage में रखता है; secrets को Git में रखने का तरीका न बनाएं। अपना काम वापस उसी original branch पर लौटकर restore करें:

```powershell
git stash apply 'stash@{0}'
git status
```

Expected changes सही वापस आएं और conflicts resolve हों तभी stash remove करें:

```powershell
git stash drop 'stash@{0}'
```

एक से अधिक stashes हों तो सही identifier चुनें; हर बार 0 मानकर apply/drop न करें। Files delete/reset करके clean status पाने का प्रयास न करें।

## 13. Merge conflict या push rejection

### Merge conflict

`git merge origin/develop` conflict दे तो:

```powershell
git status
git diff --name-only --diff-filter=U
```

IDE में conflicted files खोलें, दोनों changes का intent समझकर final code बनाएं और conflict markers हटाएं। Blind Accept All न करें। Resolve की हुई actual files stage करें, उदाहरण:

```powershell
git add src/main/java
git diff --staged
git status
git merge --continue
```

ऊपर path example है; सभी resolved files के actual paths stage करें। Editor खुले तो meaningful merge message save/close करें। Tests चलाकर push करें। Pending merge cancel करना हो तो ongoing merge में `git merge --abort` करें; merge से पहले work clean रखने से recovery आसान होती है।

### Non-fast-forward / rejected push

उसी branch पर दूसरे commits हो सकते हैं। Clean worktree पर पहले inspect करें:

```powershell
git fetch origin
git log --oneline --graph --decorate -15
git status --short --branch
```

अगर upstream set है और केवल behind हैं तो `git pull --ff-only` करें। Local/remote दोनों में नए commits हों तो collaborator से coordinate करके अपनी feature branch में उसकी remote branch merge करें, resolve/test करें, फिर normal push करें। `git push --force` से दूसरे का काम overwrite न करें।

### Local develop diverged

`git pull --ff-only origin develop` fail हो तो वहीं रोकें। `git log --oneline --left-right develop...origin/develop` से दोनों तरफ commits दिखाएं। Local unique commits को सुरक्षित working branch में बचाने और base restore करने के लिए lead की सहायता लें; reset --hard automatic fix नहीं है।

## 14. PR merge होने के बाद

GitHub पर सही PR का status Merged verify करें। Feature branch का अपना काम committed/pushed और worktree clean हो:

```powershell
git switch develop
git fetch --prune origin
git pull --ff-only origin develop
git status --short --branch
git branch -d feature/devname-note-validation
```

Squash/rebase merge के बाद -d branch not fully merged कह सकता है। PR/changes verify किए बिना -D न चलाएं; lead से review करें या branch फिलहाल रहने दें। Remote branch cleanup team/GitHub PR page से करे। Fetch --prune local feature branch delete नहीं करता।

अगला task latest develop से नई branch पर शुरू करें।

## 15. सभी repositories का read-only status एक साथ

Clones के बाद चाहें तो नीचे PowerShell block चलाएं। यह fetch/pull/switch/commit नहीं करता; केवल folders/remotes/branches/status दिखाता है।

```powershell
$techNotesRoot = 'D:\TechNotes'
$techNotesRepos = @(
  'technotes-documentation',
  'technotes-ui',
  'technotes-user-oauth-service',
  'technotes-notes-service',
  'technotes-api-gateway',
  'technotes-eureka-server',
  'technotes-config-server'
)
foreach ($repoName in $techNotesRepos) {
  $repoPath = Join-Path $techNotesRoot $repoName
  Write-Host "Repository: $repoName"
  if (Test-Path (Join-Path $repoPath '.git')) {
    git -C $repoPath remote -v
    git -C $repoPath status --short --branch
    git -C $repoPath branch -a
  } else {
    Write-Warning "Clone missing or folder is not a normal Git checkout: $repoPath"
  }
}
```

किसी repo में uncommitted work हो सकता है, इसलिए सब repositories को blindly switch/pull करने वाली script यहां नहीं दी गई। Assigned repository में section 7/8 का workflow चलाएं।

## 16. तुरंत याद रखने वाली commands

| जरूरत | Command / action |
| --- | --- |
| First local copy | git clone URL |
| सही repo | git remote -v |
| Current branch | git branch --show-current |
| सभी visible branches | git fetch origin, फिर git branch -a |
| Existing local branch पर जाएं | git switch branch-name |
| Remote-only branch local बनाएं | git switch --track origin/branch-name |
| Latest develop, clean worktree पर | git switch develop, फिर git pull --ff-only origin develop |
| नई task branch | git switch -c feature/name-task |
| क्या बदला | git status और git diff |
| Commit के लिए चुनें | git add actual-path |
| Staged content देखें | git diff --staged |
| Local snapshot | git commit -m "type: actual change" |
| First upload | git push -u origin feature/name-task |
| बाद का upload | git push |
| Review | GitHub PR: feature branch → develop |

Table में comma-separated steps अलग commands हैं; उन्हें एक command मानकर paste न करें।

## 17. Issue अभी भी आए तो क्या भेजें

Developer lead/अपनी ChatGPT को ये जानकारी दे: exact command, पूरा error text, repository name, working folder और below output. Private URLs में embedded tokens या secrets हों तो redact करें। Clone से पहले folder Git repo नहीं है तो git status/remote का error स्वाभाविक है; वह command तभी चलेगी जब clone मौजूद हो।

```powershell
Get-Location
git --version
git remote -v
git status --short --branch
git branch -a
```

Exact error के बिना credentials, access या network में से किसी एक को निश्चित कारण न मानें।

## 18. References और related documents

- [TechNotes official team Git workflow](https://github.com/techshakti55/technotes-documentation/blob/develop/docs/development/git-workflow.md) — current develop guide इस document को तैयार करते समय पढ़ी गई।
- [Documentation entry point](https://github.com/techshakti55/technotes-documentation/blob/develop/README.md)
- [First-live scope](https://github.com/techshakti55/technotes-documentation/blob/develop/docs/first-live/README.md)
- [Git clone reference](https://git-scm.com/docs/git-clone)
- [Git branch reference](https://git-scm.com/docs/git-branch)
- [GitHub cloning troubleshooting](https://docs.github.com/en/repositories/creating-and-managing-repositories/troubleshooting-cloning-errors)
- [GitHub SSH publickey troubleshooting](https://docs.github.com/en/authentication/troubleshooting-ssh/error-permission-denied-publickey)

यह commands/runbook document है; recipient के computer पर commands execute नहीं की गई हैं। Branch names, permissions, local work और build configuration execution के समय verify करें।
