# Endpoints and secrets

Every secret is a User environment variable __USER_FIRST__ sets themselves. A playbook, skill
or memory names the VARIABLE, never a value. No value ever lands in a file, a log or chat.

Set one (PowerShell, once, as __USER_FIRST__):
```powershell
[Environment]::SetEnvironmentVariable('<NAME>', '<value>', 'User')
```
Read one inside a Claude tool (the `$env:` copy goes stale after a re-paste):
```powershell
$k = [Environment]::GetEnvironmentVariable('<NAME>', 'User'); if (-not $k) { $k = $env:<NAME> }
```

| Variable | Service | Header / use | Harmless read to probe it | Set? |
|---|---|---|---|---|
| `<NAME>` | <service> | <header name> | <GET that returns 200 with a good key, 401 with a bad one> | no |

## Endpoints used by playbooks

| Service | Method + path | Purpose | Identity needed |
|---|---|---|---|
| <service> | GET <path> | <read> | read-only |
| <service> | POST <path> | <write, named playbook> | write, `$env:<NAME>` |
