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
- Organizer dashboard & event analytics
- Community and profile screens
- Firebase Firestore & Storage integration

---

## 🗂️ Main Screens

- **Welcome Screen**: Entry point, login/register
- **Home Screen**: Main navigation for users
- **Discover Events**: Browse and filter events
- **Event Details**: Info, join/check-in, see participants
- **Create Event**: (Organizer) Add new events with images
- **User Profile**: View and edit profile, sign out
- **Organizer Dashboard**: Manage events, view analytics

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

## 📝 License
MIT License. See [LICENSE](LICENSE) for details.
