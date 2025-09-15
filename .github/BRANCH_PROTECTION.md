# Branch Protection Configuration

This document outlines the recommended branch protection rules to ensure PR validation is enforced before merging to the main branch.

## Recommended Branch Protection Rules for `main`

To configure branch protection rules via GitHub UI:

1. Go to your repository's **Settings** > **Branches**
2. Add a branch protection rule for `main`
3. Configure the following settings:

### Required Settings

- ✅ **Require a pull request before merging**
  - ✅ **Require approvals**: 1 (minimum recommended)
  - ✅ **Dismiss stale PR approvals when new commits are pushed**

- ✅ **Require status checks to pass before merging**
  - ✅ **Require branches to be up to date before merging**
  - **Required status checks** (all must pass):
    - `Code Quality Checks`
    - `Build Android`
    - `Build iOS`
    - `Build macOS`
    - `Build Linux`
    - `Build Windows`

- ✅ **Require conversation resolution before merging**

- ✅ **Restrict pushes that create files that match a path**
  - Pattern: `**/*` (prevents direct pushes to main)

### Optional but Recommended

- ✅ **Require signed commits**
- ✅ **Require linear history**
- ✅ **Allow force pushes** - **Everyone** (disabled for safety)
- ✅ **Allow deletions** - **Disabled**

## Alternative: GitHub CLI Configuration

You can also set up branch protection using the GitHub CLI:

```bash
# Enable branch protection with required status checks
gh api repos/:owner/:repo/branches/main/protection \
  --method PUT \
  --field required_status_checks='{"strict":true,"contexts":["Code Quality Checks","Build Android","Build iOS","Build macOS","Build Linux","Build Windows"]}' \
  --field enforce_admins=true \
  --field required_pull_request_reviews='{"required_approving_review_count":1,"dismiss_stale_reviews":true}' \
  --field restrictions=null
```

## What This Achieves

With these branch protection rules in place:

1. **No direct commits to main** - All changes must go through pull requests
2. **All platforms must build successfully** - Prevents breaking changes for any supported platform
3. **Code quality is enforced** - Linting, formatting, and tests must pass
4. **Peer review required** - At least one approval needed before merging
5. **Up-to-date branches** - PRs must be current with main before merging

This ensures high code quality and prevents broken builds from reaching the main branch.