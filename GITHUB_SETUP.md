# GitHub Actions Setup

## Required Secrets

To enable the CI/CD pipeline, you need to add these secrets to your GitHub repository:

### Go to Repository Settings
1. Navigate to your GitHub repository
2. Click **Settings** tab
3. Click **Secrets and variables** → **Actions**

### Add Required Secrets

#### 1. EXPO_TOKEN
- **Purpose**: Allows GitHub Actions to use Expo CLI
- **How to get**:
  1. Install Expo CLI: `npm install -g @expo/cli`
  2. Login: `npx expo login`
  3. Generate token: `npx expo whoami --json`
  4. Copy the `accessToken` value
- **Add to GitHub**: 
  - Name: `EXPO_TOKEN`
  - Value: Your access token

#### 2. FIREBASE_CONFIG (Future)
- **Purpose**: Firebase configuration for deployments
- **How to get**: Copy your Firebase web config object
- **Add when ready for production builds**

## Workflow Features

The current CI pipeline (`ci.yml`) includes:

### ✅ **Automated Tests**
- TypeScript compilation check
- Dependency installation
- Code quality checks

### ✅ **Build Verification**
- Expo configuration validation
- Prebuild compatibility check
- Cross-platform build verification

### 🚀 **Future Additions**
- Automated APK builds
- Play Store deployment
- Firebase hosting deployment

## Branch Protection

Recommended branch protection rules:

### Main Branch Protection
1. Go to **Settings** → **Branches**
2. Add rule for `main` branch:
   - ✅ Require status checks to pass
   - ✅ Require branches to be up to date
   - ✅ Include administrators
   - ✅ Restrict pushes that create files with secrets

### Required Status Checks
- `Test` job must pass
- `EAS Build Check` must pass

## Manual Setup Steps

1. **Create the secrets** mentioned above
2. **Push your code** to trigger the first workflow
3. **Check Actions tab** to see the pipeline running
4. **Fix any issues** that appear in the workflow

## Testing the Pipeline

After setup:
```bash
git add .
git commit -m "feat: initial Firebase and CI setup"
git push origin main
```

Check the **Actions** tab in GitHub to see your pipeline running!

## Troubleshooting

### Common Issues:
- **EXPO_TOKEN missing**: Add the secret as described above
- **Build failures**: Check the Actions logs for specific errors
- **Permission errors**: Ensure secrets are added to the correct repository

### Getting Help:
- Check GitHub Actions logs for detailed error messages
- Verify all secrets are properly set
- Ensure Firebase configuration is complete 