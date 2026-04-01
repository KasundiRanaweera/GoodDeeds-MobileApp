# GoodDeeds App

![Flutter](https://img.shields.io/badge/Flutter-3.0%2B-blue?logo=flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-Enabled-FFCA28?logo=firebase&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-green?logo=google)

---

## Overview

**GoodDeeds** is a Flutter app for organizing and participating in community service events. It features user authentication, role-based access (Volunteer/Organizer), event management, and impact tracking, all powered by Firebase.

---

## ✨ Features

- User authentication (Firebase Auth)
- Role management: Volunteer & Organizer
- Event creation, discovery, and participation
- User profiles with editable info
- Impact points and rewards system
- Organizer attendance marking with strict 48-hour window from event start
- Volunteer event status flow: Joined -> Pending -> Completed/Missed
- Profile activity history updates after points are awarded
- Organizer dashboard & event analytics
- Community and profile screens
- Firebase Firestore & Storage integration

---


## 🗂️ Main Screens & UI Widgets

| Screen Name              | Widget/Class                | File Location                                               |
|-------------------------|-----------------------------|-------------------------------------------------------------|
| Welcome Screen           | `WelcomeScreen`             | `lib/screens/welcome_screen.dart`                           |
| Home Screen              | `HomeScreen`                | `lib/screens/home_screen.dart`                              |
| Discover Events          | `DiscoverEventsScreen`      | `lib/screens/user/discover_events_screen.dart`              |
| Event Details            | `EventDetailsScreen`        | `lib/screens/user/event_details_screen.dart`                |
| My Events                | `MyEventsScreen`            | `lib/screens/user/my_events_screen.dart`                    |
| Create Event             | `CreateEventScreen`         | `lib/screens/organizer/create_event_screen.dart`            |
| Manage Event             | `ManageEventScreen`         | `lib/screens/organizer/manage_event_screen.dart`            |
| Participants             | `ParticipantsScreen`        | `lib/screens/organizer/participants_screen.dart`            |
| User Profile             | `UserProfileScreen`         | `lib/screens/user/user_profile_screen.dart`                 |
| Organizer Dashboard      | `OrganizerDashboardScreen`  | `lib/screens/organizer/organizer_dashboard_screen.dart`     |

Each screen is implemented as a modern Flutter widget, using Material 3 design and responsive layouts. See the file locations above for the full UI code and customization options.

---

## 🧩 Data Models

### UserModel
- `id`, `name`, `email`, `phone`
- `roles`: [Volunteer, Organizer]
- `impactPoints`, `createdAt`, `updatedAt`

### EventModel
- `id`, `title`, `description`, `location`, `category`
- `impactPoints`, `eventDate`, `imageUrl`
- `organizerName`, `participantsCount`, `participantIds`
- `checkedInIds`, `awardedParticipantIds`, `status`
- `createdAt`, `updatedAt`

---

## ⚙️ Setup & Installation

1. **Clone the repo:**
	```sh
	git clone https://github.com/yourusername/gooddeeds_app.git
	cd gooddeeds_app
	```
2. **Install dependencies:**
	```sh
	flutter pub get
	```
3. **Firebase setup:**
	- Add your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) to the respective folders.
	- Update `firebase_options.dart` if needed.
4. **Run the app:**
	```sh
	flutter run
	```

5. **Deploy Firestore rules (required for attendance permissions):**
	```sh
	firebase deploy --only firestore:rules
	```

---

## Attendance & Permission Rules (Latest)

- Attendance marking window: from event start time up to exactly 48 hours after.
- Organizer role is accepted from these user fields:
	- `role: "Organizer"`
	- `roles` list containing `Organizer`
	- `isOrganizer: true`
- Organizer accounts have full Firestore access in app collections (`users`, `user_profiles`, `events`).
- Volunteer card status in My Events:
	- `Joined` before event date
	- `Pending` within the 48-hour attendance window if unmarked
	- `Completed` when organizer marks attendance
	- `Missed` after 48 hours if still unmarked
- User profile activity history and events-attended count increase only after points are awarded (`awardedParticipantIds`).

For full copy-paste security rule docs, see `FIREBASE_STORAGE_RULES.md`.

---

## 📁 Project Structure

- `lib/models/` — Data models (User, Event, etc.)
- `lib/screens/` — UI screens (user & organizer flows)
- `lib/services/` — Firebase and business logic
- `lib/widgets/` — Reusable UI components
- `lib/constants/` — App-wide constants

---

## 📚 Resources
- [Flutter Documentation](https://docs.flutter.dev/)
- [Firebase for Flutter](https://firebase.flutter.dev/)
- [Material Design](https://m3.material.io/)

---
