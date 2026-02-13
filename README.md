# 🧠 Consistency  
### A Minimal Offline Habit Tracker Built with Flutter

![Flutter](https://img.shields.io/badge/Flutter-3.x-blue)
![Platform](https://img.shields.io/badge/Platform-Android-green)
![State Management](https://img.shields.io/badge/State-Provider-orange)
![Database](https://img.shields.io/badge/Database-Isar-purple)
![License](https://img.shields.io/badge/License-MIT-lightgrey)

Consistency is a clean, offline-first habit tracking app designed to help users build sustainable routines through streak tracking, smart visualizations, reminders, and achievements — without ads, subscriptions, or cloud dependency.

---

## 🚀 Features

### 📊 Smart Habit Tracking
- Create, edit, delete habits
- Daily completion tracking
- Editable past entries
- GitHub-style activity heatmap
- Per-habit analytics dashboard

### 🔥 Streak System
- Current streak
- Best streak
- Automatic recalculation after edits
- Frequency-aware streak logic

### ⏰ Reminders & Notifications
- Per-habit reminder time picker
- Daily scheduled notifications
- Timezone-aware scheduling
- Toggle on/off per habit

### 📈 Advanced Visualizations
- Animated completion rate ring
- Monthly bar chart (last 6 months)
- Habit-specific heatmaps
- Animated stat cards
- Smooth page transitions

### 🏅 Achievement System
14 dynamically computed achievements including:

- 🌱 First Step – Create first habit  
- ✅ Getting Started – First completion  
- 🔥 Week Warrior – 7-day streak  
- 💪 Monthly Master – 30-day streak  
- 👑 Centurion – 100-day streak  
- ⭐ Half Century – 50 total check-ins  
- 💯 Century Club – 100 total check-ins  
- 🚀 Unstoppable – 500 total check-ins  
- 🎯 Triple Threat – Track 3 habits  
- 🖐️ High Five – Track 5 habits  
- 🏆 Perfect Week – All habits done 7 consecutive days  
- 🎪 Multitasker – 5+ habits in one day  
- 🌟 Perfect Day – Complete all habits (3+) in one day  

All achievements are computed dynamically from habit data (no redundant storage).

### 💾 Backup & Restore
- Export data as JSON
- Import with overwrite confirmation
- Automatic notification rescheduling
- Last backup date displayed in sidebar
- Graceful handling of invalid files

### 🎨 Clean UI & Animations
- Staggered entrance animations
- Animated progress bars & counters
- FAB bounce-in animation
- Animated dialogs (scale + fade)
- Completion bounce effect
- Light & Dark mode support

---

## 🛠 Tech Stack

| Tool | Purpose |
|------|----------|
| Flutter | UI Framework |
| Provider | State Management |
| Isar | Local NoSQL Database |
| flutter_local_notifications | Reminder Scheduling |
| fl_chart | Data Visualization |
| flutter_heatmap_calendar | Activity Heatmap |
| shared_preferences | Theme Persistence |
| file_picker | Backup System |
| timezone | Notification Timezone Handling |
| google_fonts | Typography |
| intl | Date Formatting |

---

## 🏗 Architecture

lib/
- ├── components/ # Reusable UI widgets
- ├── database/ # Isar database logic
- ├── models/ # Data models
- ├── pages/ # Screens
- ├── services/ # Achievements, Backup, Notifications
- ├── theme/ # Theme management
- └── util/ # Utility helpers


### Architectural Principles
- Separation of concerns
- Service-layer architecture
- Offline-first design
- ChangeNotifier pattern via Provider
- Clean modular structure

---

## 📱 Screens

- 🏠 Home Dashboard
- 📊 Habit Detail Page
- 🏅 Achievements Page
- 📂 Sidebar with Backup & Theme Controls

---

## 📦 Build Instructions

```bash
flutter pub get
flutter build apk --split-per-abi
