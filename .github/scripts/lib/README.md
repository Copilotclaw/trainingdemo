# `.github/scripts/lib/` — Platform-Aware Script Library

Small, focused Python scripts that work on **GitHub Actions**, **Gitea Actions**, and **local dev** — no `gh` CLI required.

## Why

`gh` is GitHub-only. When Crunch runs on Gitea, `gh` breaks. These scripts auto-detect the platform and use the right API.

## Scripts

| Script | What it does |
|--------|-------------|
| `platform.py` | Platform detection + unified API client (import this) |
| `issue_comment.py` | Add comment to an issue |
| `issue_create.py` | Create an issue |
| `issue_list.py` | List open issues (optionally filtered by label) |
| `label_ensure.py` | Create a label if it doesn't exist |

## Usage

### In other Python scripts
```python
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../lib'))
from platform import get_platform, api_post, api_get

ctx = get_platform()  # auto-detects GitHub / Gitea / local
result = api_post(ctx, f"repos/{ctx['repo']}/issues/42/comments", {"body": "hello"})
```

### CLI
```bash
python .github/scripts/lib/issue_comment.py 42 "Done! 🦃"
python .github/scripts/lib/issue_create.py "Bug title" "Description" "bug,crunch/ready"
python .github/scripts/lib/issue_list.py spark/ready
python .github/scripts/lib/label_ensure.py "spark/ready" "0075ca" "Ready for processing"
```

### In bash workflows
```yaml
- name: Comment on issue
  run: python .github/scripts/lib/issue_comment.py ${{ env.ISSUE_NUMBER }} "✅ Done"
```

## Platform Detection Logic

| Env var present | Detected as |
|----------------|------------|
| `GITEA_ACTIONS=true` | Gitea |
| `GITEA_TOKEN` set | Gitea |
| `GITHUB_ACTIONS=true` | GitHub |
| Neither | Local (uses `gh auth token` fallback) |

## Design Principles

1. **One script, one job** — don't add unrelated functionality
2. **Fail loudly** — HTTP errors raise with full response body
3. **Zero dependencies** — stdlib only (`urllib`, `json`, `os`)
4. **Testable** — each script works as `python script.py` from CLI
