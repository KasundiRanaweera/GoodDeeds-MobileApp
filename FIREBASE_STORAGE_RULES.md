# Firebase Storage Security Rules

If images are not uploading (showing a spinning circle), your Firebase Storage Rules might be too restrictive.

## Solution Steps:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **gooddeeds-app-4303c**
3. Go to **Storage** section
4. Click on **Rules** tab
5. Replace the current rules with:
```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Allow authenticated users to upload to events folder
    match /events/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null;
    }
    
    // Allow anyone to read event images
    match /events/{allPaths=**} {
      allow read;
    }
  }
}
```

6. Click **Publish** button
7. Wait 1-2 minutes for rules to deploy
8. Try uploading an image again in the app

## What These Rules Allow:

✅ **Authenticated users** can upload images to their own event folders
✅ **Anyone** can view the uploaded images (needed for download URLs)
✅ **Prevents** unauthorized uploads or malicious access

## If Upload Still Doesn't Work:

Check the **Console Output** (in VS Code terminal running `flutter run`) for error messages like:
- `Permission denied` - Update the rules above
- `User not authenticated` - Make sure user is signed in
- `Upload timeout` - Check network connection or Firebase project status
- `No image data available` - Make sure you selected an image

The enhanced logging will show:
```
=== Starting image upload ===
User UID: [uid]
File path: events/[uid]/[timestamp].jpg
Web upload: bytes size = [size]
Waiting for upload to complete...
Upload progress: 0%
Upload progress: 50%
Upload progress: 100%
Upload complete, getting download URL...
Image uploaded successfully: https://firestore.googleapis.com/...
=== Upload finished successfully ===
```
