# Code Coverage "Unknown" Status - Analysis and Fix

## Problem Analysis

The master branch shows "unknown" code coverage status due to several configuration issues:

### Root Causes

1. **Coverage Only on Pull Requests**: The GitHub workflow was configured to upload coverage only during pull requests (`if: github.event_name == 'pull_request'`), never on direct pushes to master.

2. **No Baseline Coverage**: Since coverage was never uploaded for master branch commits, Codecov had no baseline data to display.

3. **Missing Branch Configuration**: The codecov.yml lacked explicit branch handling configuration.

## Applied Fixes

### 1. Modified GitHub Workflow (`.github/workflows/shellspec.yaml`)

**Before:**
```yaml
- name: Upload coverage to Codecov
  if: github.event_name == 'pull_request'  # Only on PRs
```

**After:**
```yaml
- name: Upload coverage to Codecov
  if: always()  # On both pushes and PRs
  uses: codecov/codecov-action@v4
  with:
    files: ./coverage/cobertura.xml
    flags: shellspec-ubuntu
    name: shellspec-ubuntu-22.04
    fail_ci_if_error: false
    verbose: true
    # Override branch detection for master branch pushes
    override_branch: ${{ github.ref_name }}
    override_commit: ${{ github.sha }}
  env:
    CODECOV_TOKEN: ${{ secrets.CODECOV_TOKEN }}
```

### 2. Enhanced Codecov Configuration (`codecov.yml`)

Added explicit branch configuration:
```yaml
codecov:
  notify:
    wait_for_ci: false
  branch: master  # Explicitly set the default branch
  
# Ensure coverage is processed for all branches
branches:
  - master
  - main
```

### 3. Manual Coverage Generation Script

Created `.scripts/generate-coverage.sh` for local testing and manual coverage uploads:

```bash
# Generate coverage locally
./.scripts/generate-coverage.sh

# Generate and upload coverage
CODECOV_TOKEN=your_token ./.scripts/generate-coverage.sh upload
```

## How to Force Correct Coverage Display

### Immediate Actions

1. **Trigger a New Commit**: Push any small change to master to trigger the workflow with the new configuration.

2. **Manual Upload** (if needed):
   ```bash
   # Set your Codecov token
   export CODECOV_TOKEN="your_codecov_token_here"
   
   # Generate and upload coverage
   ./.scripts/generate-coverage.sh upload
   ```

3. **Verify Workflow**: Check that the GitHub Actions workflow runs successfully and uploads coverage.

### Long-term Solutions

1. **Regular Coverage Updates**: With the new configuration, every push to master will update coverage.

2. **Coverage Monitoring**: The workflow now generates coverage summaries in GitHub Actions step summaries.

3. **Artifact Preservation**: Coverage HTML reports are uploaded as artifacts for 30 days.

## Verification Steps

1. Check that `CODECOV_TOKEN` secret is properly configured in GitHub repository settings.
2. Ensure the next push to master triggers the workflow and uploads coverage.
3. Verify that the Codecov badge in README.md shows the correct percentage.
4. Monitor the Codecov dashboard for the repository.

## Expected Results

After the next push to master:
- ✅ Coverage badge will show actual percentage instead of "unknown"
- ✅ Codecov dashboard will have baseline data for master branch
- ✅ Future PRs will have proper coverage comparisons
- ✅ Coverage trends will be trackable over time

## Troubleshooting

If coverage still shows as "unknown":

1. **Check Workflow Logs**: Look for errors in the "Upload coverage to Codecov" step
2. **Verify Token**: Ensure `CODECOV_TOKEN` secret is valid and has proper permissions
3. **Manual Upload**: Use the provided script to manually upload coverage
4. **Contact Support**: If issues persist, check Codecov support documentation

## Files Modified

- `.github/workflows/shellspec.yaml` - Updated coverage upload conditions
- `codecov.yml` - Added explicit branch configuration
- `.scripts/generate-coverage.sh` - New manual coverage generation script (created)