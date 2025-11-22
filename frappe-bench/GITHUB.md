# GitHub Repository Setup & Control

This document explains how to upload this project to GitHub and maintain full control over your source code, preventing automatic updates from Frappe or Bench.

## Repository Structure

This repository contains:
- **Frappe Framework** (`apps/frappe/`) - The core framework code
- **LMS App** (`apps/lms/`) - Your Learning Management System
- **Payments App** (`apps/payments/`) - Payment gateway integration
- **Bench Configuration** - All bench-related configuration files

All code is tracked in a single repository, giving you complete control over all components.

## Uploading to GitHub

### Step 1: Create a GitHub Repository

1. Go to [GitHub](https://github.com) and sign in
2. Click the "+" icon in the top right corner
3. Select "New repository"
4. Choose a repository name (e.g., `frappe-lms-project`)
5. **DO NOT** initialize with README, .gitignore, or license (we already have these)
6. Click "Create repository"

### Step 2: Connect Local Repository to GitHub

After creating the repository, GitHub will show you commands. Use these:

```bash
cd /Users/shivam/Downloads/test_lms/frappe-bench

# Add the remote repository (replace YOUR_USERNAME and REPO_NAME)
git remote add origin https://github.com/YOUR_USERNAME/REPO_NAME.git

# Rename branch to main (if needed)
git branch -M main

# Push your code
git push -u origin main
```

### Step 3: Verify Upload

1. Go to your GitHub repository page
2. Verify all files are present
3. Check that sensitive files (like `sites/*/site_config.json`) are NOT visible (they should be in `.gitignore`)

## Maintaining Control Over Your Code

### ⚠️ Important: Preventing Automatic Updates

To ensure Frappe or Bench updates don't automatically affect your code:

#### 1. **Never Run These Commands:**
```bash
# ❌ DO NOT RUN - These will pull updates from Frappe/Bench repositories
bench update
bench update --pull
bench get-app frappe --branch develop
bench get-app lms --branch develop
```

#### 2. **Safe Commands (These are OK):**
```bash
# ✅ Safe - These only affect your local environment
bench start
bench --site <site> migrate
bench --site <site> console
bench build
```

#### 3. **Manual Updates (If Needed):**

If you want to update Frappe or other apps manually:

1. **Review Changes First:**
   ```bash
   # Check what would change
   git status
   git diff
   ```

2. **Create a Backup Branch:**
   ```bash
   git checkout -b backup-before-update
   git add .
   git commit -m "Backup before update"
   git checkout main
   ```

3. **Manual Update Process:**
   - If you need to update, manually review and merge changes
   - Use `git diff` to see what changed
   - Test thoroughly before committing

#### 4. **Git Configuration for Protection:**

You can add a git hook to warn you before pulling updates. Create `.git/hooks/pre-pull`:

```bash
#!/bin/bash
echo "⚠️  WARNING: Pulling from remote may update Frappe/Bench code!"
echo "Review changes carefully before merging."
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi
```

## Repository Management Best Practices

### 1. **Regular Commits**
Commit your changes regularly:
```bash
git add .
git commit -m "Description of your changes"
git push
```

### 2. **Branch Strategy**
Consider using branches for features:
```bash
git checkout -b feature/new-feature
# Make changes
git add .
git commit -m "Add new feature"
git push -u origin feature/new-feature
# Create pull request on GitHub
```

### 3. **Review Changes Before Committing**
Always review what you're committing:
```bash
git status          # See what changed
git diff            # See detailed changes
git add -p          # Interactively stage changes
```

### 4. **Protect Sensitive Data**
The `.gitignore` file is configured to exclude:
- Site configuration files (may contain passwords)
- Database files
- Log files
- Virtual environment
- Node modules
- Build artifacts

**Never commit:**
- Passwords or API keys
- Database dumps with real data
- Personal information

## Troubleshooting

### If You Accidentally Pulled Updates

1. **Check what changed:**
   ```bash
   git log --oneline -10
   git diff HEAD~1
   ```

2. **Revert if needed:**
   ```bash
   git revert <commit-hash>
   # OR
   git reset --hard <previous-commit-hash>
   ```

### If GitHub Shows Conflicts

1. **Pull latest changes:**
   ```bash
   git pull origin main
   ```

2. **Resolve conflicts manually:**
   - Open conflicted files
   - Look for `<<<<<<<`, `=======`, `>>>>>>>` markers
   - Choose which version to keep
   - Remove conflict markers

3. **Commit resolution:**
   ```bash
   git add .
   git commit -m "Resolve merge conflicts"
   git push
   ```

## Security Notes

1. **Never commit credentials** - They're in `.gitignore` but double-check
2. **Use environment variables** for sensitive data in production
3. **Review `.gitignore`** periodically to ensure it's up to date
4. **Use GitHub's secret scanning** feature if available

## Summary

✅ **DO:**
- Commit your custom code regularly
- Use branches for features
- Review changes before committing
- Keep `.gitignore` updated

❌ **DON'T:**
- Run `bench update` or similar commands
- Commit sensitive data
- Force push to main branch (unless absolutely necessary)
- Pull updates without reviewing them first

Your repository is now set up for full control. All code is tracked in your repository, and you decide when and how to update any component.

