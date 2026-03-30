# Firebase Security Rules (Storage + Firestore)

Use both rules below. Storage rules alone are not enough for role-based login.

## 1) Firebase Storage Rules

Go to [Firebase Console](https://console.firebase.google.com/) -> your project -> **Storage** -> **Rules**, then paste:

```rules
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Event images upload path used by this app
    match /events/{userId}/{allPaths=**} {
      allow write: if request.auth != null && request.auth.uid == userId;
      allow read: if true;
    }
  }
}
```

## 2) Firestore Rules

Go to your project -> **Firestore Database** -> **Rules**, then paste:

```rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isSignedIn() {
      return request.auth != null;
    }

    function isOwner(userId) {
      return isSignedIn() && request.auth.uid == userId;
    }

    // Needed for role-based login (reads users/{uid})
    match /users/{userId} {
      allow read: if isOwner(userId);
      allow create: if isOwner(userId);
      allow update: if isOwner(userId);
      allow delete: if false;
    }

    // Dedicated profile collection used by profile screens
    match /user_profiles/{userId} {
      allow read: if isOwner(userId);
      allow create: if isOwner(userId);
      allow update: if isOwner(userId);
      allow delete: if false;
    }

    // Needed for event create/read/update flow
    match /events/{eventId} {
      allow read: if isSignedIn();
      allow create: if isSignedIn();
      allow update, delete: if isSignedIn()
        && resource.data.createdByUid == request.auth.uid;
    }
  }
}
```

## 3) After Publishing Rules

1. Click **Publish** for Storage rules.
2. Click **Publish** for Firestore rules.
3. Wait 1-2 minutes.
4. Sign out and sign in again.
5. Test organizer login, event image upload, and user profile save.

## Quick Troubleshooting

- `cloud_firestore/permission-denied` after login:
  Firestore `users/{uid}` read is blocked.
- Upload spinner never ends:
  Storage write permissions or network issue.
- `User not authenticated`:
  Session expired; sign in again.
