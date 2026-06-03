# gmq_absensi

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Development & Deployment Rules

1. **Local Verification & Testing**: Always update the local codebase, compile, and test features thoroughly on your local machine before pushing.
2. **No Direct Local Firebase Deployment**: Avoid running Firebase deploy command (`npx firebase deploy`) from your local terminal to prevent unverified hot-fixes.
3. **Deployment via GitHub push**:
   - Manually push verified local code changes to the remote GitHub repository on the `main` branch.
   - Pushing to the `main` branch on GitHub will automatically trigger the GitHub Actions workflow to build and deploy the web application to Firebase Hosting.


