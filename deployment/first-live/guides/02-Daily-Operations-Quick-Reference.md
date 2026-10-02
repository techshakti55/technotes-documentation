# TechNotes — Daily Operations & Troubleshooting Reference

**Date:** 2 October 2026  
**Owner:** Shakti Singh  
**Audience:** Jo developer/admin running TechNotes ko check ya maintain karega.

Yeh document everyday use ke liye hai. Detailed reasons ke liye [Complete AWS Guide](01-AWS-Deployment-Complete-Guide.md) dekho. Release inventory aur completion status ke liye [Handover](03-First-Live-Status-and-Handover.md).

> Normal day par website ko restart karna zaroori nahi. Running app ko pehle check karo. Sirf problem ya planned update mein stop/restart/deploy karo.

## 1. Sabse pehle: sahi terminal

| Task | Kahan |
|---|---|
| Docker containers, DB backup, server RAM, cron | Ubuntu AWS terminal |
| Laptop DNS / local browser connectivity | Windows PowerShell |
| EC2 instance/role/security group | AWS Console |
| Domain A records | GoDaddy DNS Console |
| Feature branch / source changes | Respective local repository or GitHub |

AWS browser terminal open: AWS Console → EC2 → Instances → select `i-07284b353e2fae538` → Connect → EC2 Instance Connect → username `ubuntu` → Connect. This was the working connection path in this deployment.

Terminal connect hone ke baad:

```bash
cd ~/technotes-deployment
pwd
```

Expected path `/home/ubuntu/technotes-deployment`. Directory check important hai: wrong folder se Compose command correct config nahi uthayegi.

## 2. Daily five-minute check

**Ubuntu AWS terminal:**

```bash
sudo docker compose ps -a
```

Expected: `postgres` aur `mongodb` healthy; `oauth`, `notes`, `gateway`, `ui`, `proxy` Up; `mongo-init` Exited (0). Names ke aage `technotes-production-` prefix normal hai.

```bash
curl --fail --connect-timeout 10 --max-time 30 -I https://technotes.co.in
```

Expected status 200. Yeh UI entry point ka check hai, login ka full test nahi.

```bash
curl --fail --connect-timeout 10 --max-time 30 https://technotes.co.in/api/v1/public/notes
```

Expected JSON with `items`, pagination fields. 14 published notes recorded the; count future content changes ke saath badal sakta hai.

```bash
curl --fail --connect-timeout 10 --max-time 30 https://auth.technotes.co.in/oauth2/jwks
```

Expected `keys` JSON. Yeh public verification keys hain, access token nahi.

```bash
tail -n 20 backups/backup.log
```

Expected latest completed scheduled run mein `BACKUP UPLOADED: ...`. Empty log before first scheduled run normal ho sakta hai. Last successful timestamp check karo; purane success message se aaj ka backup assume mat karo.

Finally browser se ek public note kholo. Login behavior badla ho ya release deploy hui ho to admin login/workspace bhi check karo.

## 3. Server ki capacity check

**Ubuntu AWS terminal:**

```bash
free -h
```

`available` RAM aur swap usage dekho. Observed host 1.9 GiB RAM + 2 GiB swap. Increasing swap/slow response capacity investigation ka signal hai; ek nonzero swap reading alone failure nahi.

```bash
df -h /
```

Free disk check. Backup folders, image TARs aur Docker layers disk use karte hain. Data delete karke blind cleanup mat karo.

```bash
sudo docker stats --no-stream
```

Container-wise current CPU/RAM snapshot. `--no-stream` output dekar return karta hai, continuous screen nahi chalata.

```bash
sudo docker system df
```

Images, containers aur volumes ka disk usage summary. Yeh read-only summary hai. `prune --volumes` is guide ka daily command nahi.

## 4. Logs kaise dekhein?

**Ubuntu AWS terminal:**

```bash
sudo docker compose logs --tail 80 oauth notes gateway proxy
```

Recent logs. Service-specific investigation mein:

```bash
sudo docker compose logs --tail 80 oauth
```

```bash
sudo docker compose logs --tail 80 notes
```

```bash
sudo docker compose logs --tail 80 mongo-init
```

Init job fails ho to last command useful. Exit 0 normal; nonzero code inspect karo.

Continuous logs chahiye tab:

```bash
sudo docker compose logs --tail 50 -f gateway
```

`Ctrl+C` log viewing stop karta hai. Is detached stack mein logs command close karne se Gateway stop nahi hota.

Shared log screenshot se passwords, Authorization headers, signed URLs aur private configuration remove karo. `docker compose config` without `--quiet` actual env values print kar sakta hai.

## 5. Start, stop, restart aur update mein difference

| Action | Kab | Impact |
|---|---|---|
| Check status | Daily / issue investigation | No intended downtime |
| `up -d` | Stopped/missing stack intentionally start | Creates/starts; changed configuration may recreate services |
| `stop` | Planned downtime | Containers stop; persistent volumes retained |
| `restart <service>` | Deliberate restart of existing config | Brief interruption; changed env not loaded as new config |
| Recreate affected service | Reviewed config/image update | Runs new config; validate and acceptance test |
| EC2 stop | Whole server downtime | Website + cron stop; charges for retained resources can remain |
| Browser disconnect | End your console session | Detached containers can keep running |

**Ubuntu AWS terminal — intentional start:**

```bash
cd ~/technotes-deployment
sudo docker compose --env-file .env config --quiet
sudo docker compose up -d
```

Quiet validation mein output nahi aaye aur exit successful ho to expected. Start ke baad status/public/login check karo.

**Planned downtime only:**

```bash
sudo docker compose stop
```

**Specific service restart only when needed:**

```bash
sudo docker compose restart gateway
```

Restart ko DNS timeout ka first fix mat banao. Changed `.env` ko `restart` automatically apply nahi karta; reviewed recreation needed ho sakti hai.

`down -v`, database volume deletion, root filesystem wipe aur EC2 termination routine operations nahi. Docker volume backup ka substitute bhi nahi.

## 6. Manual backup: current recommended command

**Ubuntu AWS terminal, ubuntu user:**

```bash
cd ~/technotes-deployment
./scripts/backup.sh
```

Expected final line:

```text
BACKUP UPLOADED: s3://technotes-deploy-20261002-shakti/production-backups/<UTC-timestamp>/
```

This creates three files per successful run:

| File | Meaning |
|---|---|
| `oauth.dump` | PostgreSQL custom-format database archive |
| `notes.archive.gz` | MongoDB Notes compressed archive |
| `SHA256SUMS` | Checksums for both files |

Directory `backups/<UTC-timestamp>/` locally; corresponding timestamp folder in S3. Filenames note bodies nahi dikhati, but files sensitive DB data contain karti hain. Local permissions private, S3 access role-controlled.

Script password prompt maange bina `sudo -n` use karti hai. Role credentials AWS CLI ko milni chahiye. Overlapping script run ho to lock error return karega; second run ko force mat karo.

Failure par final success message nahi aana chahiye. Partial local/S3 folder ho sakta hai; usko completed backup mat label karo. First script run 14 Notes docs/14 revisions/2 categories ke saath successful tha.

## 7. Daily schedule dekhna

**Ubuntu AWS terminal:**

```bash
timedatectl show --property=Timezone --value
systemctl is-active cron
crontab -l
```

Recorded outputs: `Etc/UTC`, `active`, and:

```cron
30 21 * * * /home/ubuntu/technotes-deployment/scripts/backup.sh >> /home/ubuntu/technotes-deployment/backups/backup.log 2>&1
```

Schedule: 21:30 UTC / next day 03:00 IST. Server timezone change karoge to cron timing review karo. Line start mein `#` nahi hona chahiye. Duplicate line mat add karo.

Cron installed hai; first scheduled execution document cutoff par pending hai. EC2 band hua to normal cron missed job automatically replay nahi karta. Failure notification abhi automatic nahi; log regularly inspect karo.

Log file permissions:

```bash
ls -l backups/backup.log
```

Owner private read/write expected. Existing setup mode 600 rakhta hai. Local retention aur backup.log rotation pending hain; indefinite growth monitor karo.

## 8. S3 backup aur IAM check

**Ubuntu AWS terminal:**

```bash
aws sts get-caller-identity --query Arn --output text --no-cli-pager
```

Expected role name `TechNotesProductionBackupRole` aur instance session. Wrong/missing identity ho to Console mein EC2 role attachment check karo; laptop IAM user access keys is server par paste mat karo.

```bash
aws s3 ls s3://technotes-deploy-20261002-shakti/production-backups/ --region ap-south-1
```

Timestamp prefixes list honge. One run's files check karne ka example:

```bash
aws s3 ls s3://technotes-deploy-20261002-shakti/production-backups/20261002T142855Z/ --region ap-south-1
```

Expected OAuth, Notes aur SHA256SUMS from script run. Latest timestamp substitute karo only after listing real existing folder.

### Downloaded backup checksums verify

**Reference, no production restore:**

```bash
mkdir -p backups/verify-20261002T142855Z
chmod 700 backups/verify-20261002T142855Z
aws s3 cp s3://technotes-deploy-20261002-shakti/production-backups/20261002T142855Z/ backups/verify-20261002T142855Z/ --recursive --region ap-south-1
```

Then:

```bash
cd backups/verify-20261002T142855Z
sha256sum -c SHA256SUMS
cd ~/technotes-deployment
```

Expected both `OK`. This latest-run checksum example has not been executed by this document's author on EC2. Earlier timestamp's actual byte-comparison succeeded in the user session.

Download match/archive readability/full restore are separate levels of verification. Production database restore requires a planned procedure; don't improvise it from checksum commands.

## 9. Website timeout: check DNS before restarting apps

**Windows PowerShell on laptop:**

```powershell
ipconfig /flushdns
Resolve-DnsName technotes.co.in -Type A
Resolve-DnsName auth.technotes.co.in -Type A
```

Both current IP `43.205.62.80` expected. `52.66.243.132` historical old IP hai.

```powershell
curl.exe --noproxy "*" --connect-timeout 10 --max-time 30 --resolve technotes.co.in:443:43.205.62.80 -I https://technotes.co.in
```

Normal DNS old IP dikhaye but forced IP 200 de to resolver cache/update investigate karo. DNS records immediately repeat-edit karna necessary nahi.

Auth test:

```powershell
curl.exe --noproxy "*" --connect-timeout 10 --max-time 30 --resolve auth.technotes.co.in:443:43.205.62.80 https://auth.technotes.co.in/oauth2/jwks
```

Expected keys JSON. Login full browser flow alag verify karo. Browser-only stale state ho to all Incognito windows close karke new window mein HTTPS site kholo. Windows DNS flush Chrome/network ke har cache ko necessarily instantly reset nahi karta.

**Ubuntu AWS terminal:**

```bash
getent ahostsv4 technotes.co.in
getent ahostsv4 auth.technotes.co.in
```

Server aur laptop results compare karo. New-IP forced connection bhi timeout ho to SG 443, Elastic IP association, proxy/container logs aur network path investigate karo.

## 10. Common issue: kaunsa next check?

| Issue | Pehla check | Kya blindly nahi karna |
|---|---|---|
| Homepage timeout | DNS + forced-IP curl | Databases reset |
| Public page works, login timeout | Auth domain DNS / JWKS | All containers restart |
| Login password invalid | Correct production user/password | OWNER_PASSWORD edit ko automatic reset assume |
| Save 412 | Current ETag/If-Match and Caddy config | Concurrency validation disable |
| Backup Permission denied | Directory owner; shell redirection | Whole `/var/lib/docker` chown |
| AWS NoCredentials | Role ARN/EC2 IAM role | Access keys paste |
| S3 AccessDenied | Identity and exact allowed prefix | FullS3Access add |
| Container restart loop | Service logs and DB/key dependencies | Repeated rebuild without evidence |
| mongo-init Exited (0) | Successful expected job | Treat as failed app |
| Disk nearly full | df/docker usage/backups/logs | Delete live volumes |
| Script bash syntax error | Clean paste / `bash -n` | Duplicate pasted commands run |

## 11. Caddy edit: validate before reload

Only intentional proxy config change mein. Current first-live config omits `encode zstd gzip` to preserve API ETags.

**Ubuntu AWS terminal — syntax validation:**

```bash
sudo docker compose exec -T proxy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
```

Validation successful ho tab reload:

```bash
sudo docker compose exec -T proxy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile
```

Yeh future operational reference hai. Reload success ke baad homepage, public API, login aur save workflow test karo. Existing config ka private backup before edit rakho.

## 12. Session handling aur nano

| Action | Meaning |
|---|---|
| `nano <file>` | File editor |
| Ctrl+O, Enter | Save filename confirm |
| Ctrl+X | Exit editor |
| Ctrl+C at prompt/foreground command | Cancel current foreground action |
| `read -s` hides text | Password/URL input visible nahi, necessarily frozen nahi |
| Browser refresh/reconnect | New shell may lose variables; files/containers verify |

Right-click Paste once useful tha. Copy ki line repeat ho to command run se pehle cancel karo. Presigned URL ya token ko document/share nahi karna.

## 13. Update karne se pehle short checklist

- Correct service branch/PR and tests ready.
- New build/version identifiable; previous working image retained.
- Fresh backup succeeded and destination recorded.
- Intended file/image diff reviewed.
- Runtime `.env` and secret mounts preserved.
- Compose quiet validation passed.
- Deployment ke baad browser + public/protected workflow tested.
- Database migrations ki rollback compatibility understood.

GitHub documentation merge running EC2 files auto-update nahi karta. `restart` aur new image/config rollout same thing nahi. Deployment directory se deliberate change karo.

## 14. Current remaining operations

First scheduled backup evidence, full EC2 reboot recovery, encrypted off-server key/config recovery, retention/log rotation, failure alerts, cost review, immutable image manifest aur `www` behavior check pending hain. Browser acceptance after Elastic IP change user ne confirm ki.

Useful official links: [Docker restart behavior](https://docs.docker.com/engine/containers/start-containers-automatically/), [Caddy HTTPS](https://caddyserver.com/docs/automatic-https), [EC2 role attachment](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/attach-iam-role.html). Actual project settings ka detailed record main guide mein hai.
