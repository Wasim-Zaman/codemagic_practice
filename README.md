# Flutter App with Automated CI/CD Pipeline

![Flutter](https://img.shields.io/badge/Flutter-3.10.0-blue.svg)
![Codemagic](https://img.shields.io/badge/CI/CD-Codemagic-orange.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

A Flutter application with automated build and deployment pipeline using Codemagic CI/CD. This project demonstrates how to automatically build and upload APKs to Google Drive for easy distribution to testers and stakeholders.

## Features

- **Automated Builds**: Continuous integration with Codemagic
- **Google Drive Integration**: Automatic APK uploads to Google Drive
- **Version Tracking**: Date-stamped APK files for easy version management
- **Secure Authentication**: Service account authentication with Google APIs

## CI/CD Pipeline

This project uses Codemagic for continuous integration and delivery with the following workflow:

1. Code is pushed to the main branch
2. Codemagic automatically triggers a build
3. Flutter APK is generated
4. APK is uploaded to Google Drive using a service account
5. Build artifacts are available in Codemagic dashboard

> 📚 **Detailed Guide**: For a comprehensive step-by-step guide on setting up the Google Drive integration, see our [Complete CI/CD Setup Guide](./GUIDE.md).

## Setup Instructions

### Prerequisites

- Flutter SDK
- Google Cloud account
- Codemagic account
- Git

### Local Development

1. Clone the repository:

   ```bash
   git clone https://github.com/yourusername/your-repo-name.git
   cd your-repo-name
   ```

2. Install dependencies:

   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

### Setting Up CI/CD Pipeline

#### Google Cloud Setup

1. Create a Google Cloud project
2. Enable the Google Drive API
3. Create a service account with appropriate permissions
4. Generate and download a JSON key for the service account
5. Share your Google Drive folder with the service account email

#### Codemagic Setup

1. Add your project to Codemagic
2. Create an environment variable group named "SECRET"
3. Add your service account JSON as `GCLOUD_SERVICE_ACCOUNT_JSON` (mark as secure)
4. Configure your workflow using the provided `codemagic.yaml`

## Project Structure

```
├── lib/                  # Application source code
├── android/              # Android-specific configuration
├── ios/                  # iOS-specific configuration
├── upload_apk.sh         # Script for uploading APKs to Google Drive
├── codemagic.yaml        # CI/CD configuration
├── GUIDE.md              # Detailed setup guide
└── README.md             # Project documentation
```

## Deployment

The application is automatically built and deployed when code is pushed to the main branch. The latest APK can be found in the shared Google Drive folder.

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature-name`
3. Commit your changes: `git commit -m 'Add some feature'`
4. Push to the branch: `git push origin feature/your-feature-name`
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgements

- [Flutter](https://flutter.dev/) for the SDK
- [Codemagic](https://codemagic.io/) for CI/CD services
- [Google Drive API](https://developers.google.com/drive) for storage integration
