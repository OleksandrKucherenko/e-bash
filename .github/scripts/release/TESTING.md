# Testing the Release Pipeline

This guide shows you how to test the release pipeline locally and in CI before creating an actual release.

## 🧪 Local Testing

### Quick Test (All Scripts)

Run the automated test script:

```bash
# Test with default version (1.2.3-test)
./.github/scripts/release/test-local.sh

# Test with specific version
./.github/scripts/release/test-local.sh "1.0.0-rc.1"
```

This will:
1. ✅ Validate the version format
2. ✅ Run ShellCheck on all scripts
3. ✅ Verify required files exist
4. ✅ Create a test archive
5. ✅ Generate release notes
6. ✅ Display release summary

**Cleanup after testing:**
```bash
rm e-bash.*.zip e-bash.*.zip.sha256 release_notes.md
```

### Individual Script Testing

Test each script independently:

#### 1. Validate Version Format

```bash
# Valid versions (should pass)
./.github/scripts/release/validate-version.sh "1.2.3" "v1.2.3"
./.github/scripts/release/validate-version.sh "1.0.0-alpha" "v1.0.0-alpha"
./.github/scripts/release/validate-version.sh "2.1.0-rc.1+build.123" "v2.1.0-rc.1+build.123"

# Invalid versions (should fail)
./.github/scripts/release/validate-version.sh "1.2" "v1.2"
./.github/scripts/release/validate-version.sh "1.2.3.4" "v1.2.3.4"
```

#### 2. Check Code Quality

```bash
./.github/scripts/release/check-quality.sh
```

This runs ShellCheck on all `.sh` files in `.scripts/` and `bin/` directories.

#### 3. Verify Distribution Contents

```bash
./.github/scripts/release/verify-contents.sh
```

Ensures all required files and directories exist.

#### 4. Create Archive

```bash
# Create test archive
./.github/scripts/release/create-archive.sh "1.2.3-test"

# Verify archive was created
ls -lh e-bash.1.2.3-test.zip
cat e-bash.1.2.3-test.zip.sha256

# Verify archive integrity manually
unzip -t e-bash.1.2.3-test.zip
```

#### 5. Generate Release Notes

```bash
VERSION="1.2.3-test"
ARCHIVE="e-bash.${VERSION}.zip"
CHECKSUM=$(cat "${ARCHIVE}.sha256" | cut -d' ' -f1)

./.github/scripts/release/generate-release-notes.sh \
  "$VERSION" \
  "v$VERSION" \
  "$(git rev-parse HEAD)" \
  "$CHECKSUM" \
  "$ARCHIVE"

# View generated notes
cat release_notes.md
```

#### 6. Generate Release Summary

```bash
./.github/scripts/release/release-summary.sh \
  "$VERSION" \
  "v$VERSION" \
  "$(git rev-parse HEAD)" \
  "$CHECKSUM" \
  "$ARCHIVE" \
  "OleksandrKucherenko/e-bash"
```

---

## 🚀 CI Testing (Manual Dispatch)

Test the full workflow in GitHub Actions without creating a real release.

### Method 1: Workflow Dispatch (Recommended)

1. **Navigate to GitHub Actions:**
   - Go to: https://github.com/OleksandrKucherenko/e-bash/actions
   - Select "Release Distribution" workflow

2. **Run Workflow Manually:**
   - Click "Run workflow" button
   - Branch: Select your branch (e.g., `claude/create-distribution-pipeline-01BoVdrkogQ7UcN8jGwPx62w`)
   - Tag: Enter a test version (e.g., `v1.2.3-test`)
   - Click "Run workflow"

3. **Monitor Execution:**
   - Watch each step execute
   - Review logs for any issues
   - Check the step summary at the end

4. **Verify Output:**
   - A GitHub release will be created with tag `v1.2.3-test`
   - Download and verify the ZIP archive
   - Check the release notes
   - Verify the checksum

5. **Cleanup:**
   ```bash
   # Delete the test release via GitHub UI or CLI
   gh release delete v1.2.3-test --yes --cleanup-tag
   ```

### Method 2: Push Test Tag

Create and push a test tag to trigger the workflow:

```bash
# Create test tag
git tag v1.2.3-test

# Push tag to trigger workflow
git push origin v1.2.3-test

# Watch the workflow run
# Monitor at: https://github.com/OleksandrKucherenko/e-bash/actions

# Cleanup after testing
git tag -d v1.2.3-test                    # Delete local tag
git push origin --delete v1.2.3-test      # Delete remote tag
gh release delete v1.2.3-test --yes       # Delete release
```

---

## 🔍 Validation Checklist

Before creating a production release, verify:

### Local Tests
- [ ] All individual scripts pass
- [ ] Test script completes successfully
- [ ] Archive creates correctly with valid checksum
- [ ] Release notes generate with correct format
- [ ] No ShellCheck warnings (or acceptable warnings)

### CI Tests
- [ ] Workflow completes successfully
- [ ] All steps pass (green checkmarks)
- [ ] Archive uploads to GitHub release
- [ ] Release notes display correctly
- [ ] Checksum verification works
- [ ] Pre-release detection works (for `-alpha`, `-beta`, etc.)

### Manual Verification
- [ ] Download the test ZIP archive
- [ ] Verify checksum matches: `sha256sum -c e-bash.*.zip.sha256`
- [ ] Extract and inspect contents
- [ ] All required files present (`.scripts/`, `bin/`, `docs/`, `demos/`, `README.md`, `LICENSE`)
- [ ] No unwanted files (`.git/`, `node_modules/`, etc.)

---

## 🐛 Troubleshooting

### Script Fails Locally

**Issue:** Permission denied when running scripts

```bash
# Fix: Make scripts executable
chmod +x .github/scripts/release/*.sh
```

**Issue:** Script not found

```bash
# Fix: Run from repository root
cd /path/to/e-bash
./.github/scripts/release/test-local.sh
```

### Workflow Fails in CI

**Issue:** ShellCheck not installed

- Check if `check-quality.sh` auto-installs in CI
- Verify `CI` environment variable is set

**Issue:** Archive creation fails

- Check if required directories exist
- Verify `zip` command is available
- Review `verify-contents.sh` output

**Issue:** Release creation fails

- Verify `GITHUB_TOKEN` has correct permissions
- Check if tag already exists
- Review cleanup step logs

### Validation Issues

**Issue:** Version validation fails for valid semver

```bash
# Test the regex locally
VERSION="1.2.3-beta.1"
SEMVER_REGEX='^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$'
[[ "$VERSION" =~ $SEMVER_REGEX ]] && echo "Valid" || echo "Invalid"
```

---

## 📊 Test Results

After running tests, you should see:

**Local Test Success:**
```
=================================================
✅ All Tests Passed!
=================================================

📦 Generated files:
  - e-bash.1.2.3-test.zip
  - e-bash.1.2.3-test.zip.sha256
  - release_notes.md
```

**CI Test Success:**
```
## 🎉 Release Created Successfully!

### 📋 Release Information
- Version: 1.2.3-test
- Tag: v1.2.3-test
- Commit: abc123d
- Release URL: https://github.com/.../releases/tag/v1.2.3-test

### 📦 Distribution Package
- Archive: e-bash.1.2.3-test.zip
- SHA256: [checksum]
```

---

## 🎯 Production Release

Once all tests pass, create a production release:

```bash
# Create and push production tag
git tag v1.2.3
git push origin v1.2.3

# Or use manual dispatch with production version
# Go to Actions → Release Distribution → Run workflow
# Enter: v1.2.3
```

The workflow will automatically:
1. Validate the version
2. Run quality checks
3. Create the distribution archive
4. Generate release notes
5. Publish to GitHub Releases
6. Display success summary

---

## 💡 Tips

1. **Always test locally first** before pushing to CI
2. **Use test versions** with `-test` suffix for CI testing
3. **Review logs** carefully in GitHub Actions
4. **Clean up test releases** to avoid confusion
5. **Document any issues** found during testing
6. **Keep the test script updated** as pipeline evolves
