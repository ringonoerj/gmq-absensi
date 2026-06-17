# GMQ Absensi V2

A cross-platform Flutter application for educational/school attendance tracking, integrated with Supabase (backend/database) and Hive (for offline caching).

## Features

- **Role-Based Access Control**:
  - **Operator**: Record daily attendance for students and teachers (supports offline logging with automatic synchronization).
  - **Supervisor**: View reports, statistics, charts, and export data.
  - **Superadmin**: Full master-data management (Units, Classes, Students, Teachers, Users), configuration of teacher incentives, and database backup/restore.
- **Multi-Profile Attendance Support**: Teachers and students can be registered in and record attendance across multiple different units and classes in a single day.
- **National & Unit-Specific Holiday Validation**: Integrated validation against the `libur_nasional` database. Attendance inputs are blocked on holiday dates for the respective units, displaying a "Libur" status.
- **Comprehensive Reporting Metrics**: Summarized report views for both desktop and mobile platforms displaying five metrics: **Hadir (H), Izin (I), Sakit (S), Alpha (A), and Libur (L)**. Optimized with batch-loading mechanisms to prevent N+1 query performance hits.
- **A-Z Alphabetical Standardization**: Ensured all dropdown menus, list views, and summaries are consistently sorted alphabetically in ascending order (A-Z).
- **Offline Mode Support**: Auto-cache statistics and queue attendance entries locally via Hive when offline, with seamless background synchronization once an internet connection is established.
- **Dynamic Banners & Charts**: Live statistics visualizations and system-wide announcements managed via a central configuration panel.

## Technology Stack

- **Frontend**: Flutter & Dart (Provider state management)
- **Local Storage**: Hive & SharedPreferences
- **Backend & Auth**: Supabase (PostgreSQL)
- **Report Exporting**: Excel Spreadsheet generation helper
- **Deployment**: Firebase Hosting & GitHub Actions CI/CD

## Getting Started

### Prerequisites

- Flutter SDK (version `>=3.0.0 <4.0.0`)
- Node.js (for backend management scripts)

### Installation

1. Navigate to the app directory:
   ```bash
   cd gmq_absensi
   ```
2. Fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Run the application:
   ```bash
   flutter run
   ```

### Building for Android

To build a release APK for Android:
1. Navigate to the app directory:
   ```bash
   cd gmq_absensi
   ```
2. Run the build command:
   ```bash
   flutter build apk --release
   ```
The generated APK will be located at: `gmq_absensi/build/app/outputs/flutter-apk/app-release.apk`


## Development & Deployment Rules

1. **Local Verification & Testing**: Always update the local codebase, compile, and test features thoroughly on your local machine before pushing.
2. **No Direct Local Firebase Deployment**: Avoid running Firebase deploy command (`npx firebase deploy`) from your local terminal to prevent unverified hot-fixes.
3. **Deployment via GitHub push**:
   - Manually push verified local code changes to the remote GitHub repository on the `main` branch.
   - Pushing to the `main` branch on GitHub will automatically trigger the GitHub Actions workflow to build and deploy the web application to Firebase Hosting.
