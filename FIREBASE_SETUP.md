# Firebase Setup Instructions

## Step 1: Create Firebase Project

1. **Go to Firebase Console**: https://console.firebase.google.com/
2. **Click "Add Project"**
3. **Enter project name**: `snapagram` (or your preferred name)
4. **Continue through setup**:
   - Enable Google Analytics (recommended)
   - Choose or create Google Analytics account
   - Accept terms and create project

## Step 2: Enable Required Services

In your Firebase Console, enable these services:

### Authentication
1. Go to **Authentication** → **Sign-in method**
2. Enable **Email/Password** provider
3. Enable **Google** provider (add your support email)

### Firestore Database
1. Go to **Firestore Database**
2. Click **Create database**
3. Choose **Start in test mode** (we'll secure later)
4. Select your preferred location

### Storage
1. Go to **Storage**
2. Click **Get started**
3. Use default security rules for now

### Cloud Messaging (for notifications)
1. Go to **Cloud Messaging**
2. No setup required, just note it's available

## Step 3: Add Android App

1. **Click Android icon** in Project Overview
2. **Android package name**: `com.snapagram.app`
3. **App nickname**: `SnapAGram`
4. **Debug signing certificate SHA-1**: (optional for now)
5. **Click "Register app"**

## Step 4: Download Configuration

1. **Download `google-services.json`**
2. **Place in project root** (same folder as `app.json`)
3. **IMPORTANT**: This file is in `.gitignore` - don't commit it!

## Step 5: Get Web Configuration

1. Go to **Project Settings** (gear icon)
2. Scroll to **Your apps** section
3. Click **Web app** (</>) icon
4. Register web app: `SnapAGram Web`
5. **Copy the config object** from the generated code

## Step 6: Update Firebase Config

1. Open `firebase.config.js`
2. Replace the placeholder config with your actual config:

```javascript
const firebaseConfig = {
  apiKey: "your-actual-api-key",
  authDomain: "your-project.firebaseapp.com",
  projectId: "your-actual-project-id",
  storageBucket: "your-project.firebasestorage.app",
  messagingSenderId: "123456789",
  appId: "1:123456789:web:abcdef123456"
};
```

## Step 7: Test the Setup

Run the app:
```bash
npm start
```

The app should build without Firebase errors.

## Security Notes

- `google-services.json` contains sensitive keys
- Never commit Firebase config files to version control
- The web config is less sensitive but still keep it private
- We'll implement proper security rules in later phases

## Troubleshooting

- **Build errors**: Make sure `google-services.json` is in project root
- **Module not found**: Run `npm install` to install dependencies
- **Configuration errors**: Double-check the config matches your Firebase project

## Next Steps

After setup, we'll implement:
1. User authentication
2. Firestore security rules
3. Cloud Functions for TTL
4. Push notifications 