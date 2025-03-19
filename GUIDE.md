# Complete Guide: Automating APK Uploads to Google Drive with Codemagic CI/CD

This guide walks you through setting up automated APK uploads to Google Drive using Codemagic CI/CD. This is perfect for sharing app builds with your team or clients without manual intervention.

## Step 1: Create a Google Cloud Project

1. Go to the [Google Cloud Console](https://console.cloud.google.com/)
2. Click "Create Project" or select an existing project
3. Give your project a name (e.g., "App-Releases")
4. Click "Create"

## Step 2: Enable the Google Drive API

1. In your Google Cloud project, navigate to "APIs & Services" > "Library"
2. Search for "Google Drive API"
3. Click on "Google Drive API" in the results
4. Click "Enable"

## Step 3: Create a Service Account

1. In your Google Cloud project, navigate to "IAM & Admin" > "Service Accounts"
2. Click "Create Service Account"
3. Enter a name (e.g., "app-release-uploader") and description
4. Click "Create and Continue"
5. For the role, select "Basic" > "Editor" (or a more restrictive role if preferred)
6. Click "Continue" and then "Done"

## Step 4: Create and Download Service Account Key

1. From the Service Accounts list, click on the email address of your new service account
2. Go to the "Keys" tab
3. Click "Add Key" > "Create new key"
4. Select "JSON" as the key type
5. Click "Create"
6. The key file will be automatically downloaded to your computer
7. Keep this file secure - it grants access to your Google Drive!

## Step 5: Share Your Google Drive Folder

1. Go to [Google Drive](https://drive.google.com/)
2. Create a folder where you want to store your APKs (or use an existing one)
3. Right-click on the folder and select "Share"
4. In the "Add people and groups" field, enter the email address of your service account (found in the JSON key file under "client_email")
5. Set the permission to "Editor"
6. Click "Share"
7. Note the folder ID from the URL when you open the folder (it's the long string after `/folders/` in the URL)

## Step 6: Set Up Codemagic Project

1. Sign in to [Codemagic](https://codemagic.io/)
2. Add your Flutter project
3. Create a new workflow or edit an existing one

## Step 7: Add Service Account Key as Environment Variable

1. In your Codemagic project, go to "Environment variables"
2. Create a new variable group (e.g., "SECRET")
3. Add a new variable:
   - Name: `GCLOUD_SERVICE_ACCOUNT_JSON`
   - Value: Paste the entire content of your service account JSON key file
4. Make sure to mark it as "Secure" (sensitive)
5. Save the variable

## Step 8: Create the Upload Script

Create a file named `upload_apk.sh` in your project root:

```bash
#!/bin/bash

# Define variables
APK_PATH=build/app/outputs/flutter-apk/app-release.apk
FOLDER_ID="YOUR_FOLDER_ID"  # Replace with your actual folder ID
SERVICE_ACCOUNT_FILE="gcloud-service-key.json"

# Check if APK exists
if [ ! -f "$APK_PATH" ]; then
    echo "Error: APK file not found at $APK_PATH"
    exit 1
fi

# Debug: Check if the environment variable exists
echo "Checking for GCLOUD_SERVICE_ACCOUNT_JSON variable..."
if [ -z "$GCLOUD_SERVICE_ACCOUNT_JSON" ]; then
    echo "Error: GCLOUD_SERVICE_ACCOUNT_JSON environment variable is not set"
    exit 1
fi

# Write the JSON content to file
printf '%s' "$GCLOUD_SERVICE_ACCOUNT_JSON" > $SERVICE_ACCOUNT_FILE

# Debug: Check the content of the service account file
echo "First 50 characters of service account file:"
head -c 50 $SERVICE_ACCOUNT_FILE
echo # New line

# Get the current date for the APK name
CURRENT_DATE=$(date +"%Y-%m-%d_%H-%M")
APK_NAME="app-release_${CURRENT_DATE}.apk"

echo "Uploading APK as $APK_NAME to Google Drive folder $FOLDER_ID..."

# Create JWT signature using Python
JWT_SIGNATURE=$(python3 -c "
import jwt
import sys

try:
    with open('$SERVICE_ACCOUNT_FILE') as f:
        import json
        sa = json.load(f)

    header = {'alg': 'RS256', 'typ': 'JWT'}
    payload = {
        'iss': sa['client_email'],
        'scope': 'https://www.googleapis.com/auth/drive',
        'aud': 'https://oauth2.googleapis.com/token',
        'exp': int($(date +%s)) + 3600,
        'iat': int($(date +%s))
    }

    token = jwt.encode(payload, sa['private_key'], algorithm='RS256', headers=header)
    print(token)
except Exception as e:
    print(f'Error creating JWT: {str(e)}', file=sys.stderr)
    sys.exit(1)
")

echo "JWT token: $JWT_SIGNATURE"

# Exchange JWT for access token
OAUTH_RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=$JWT_SIGNATURE" \
  https://oauth2.googleapis.com/token)

echo "OAuth response: $OAUTH_RESPONSE"

# Extract access token from response
ACCESS_TOKEN=$(echo $OAUTH_RESPONSE | jq -r '.access_token')

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" == "null" ]; then
    echo "Error: Failed to get access token"
    exit 1
fi

echo "Successfully obtained access token"

# First, try to get folder info to check permissions
FOLDER_INFO=$(curl -s -H "Authorization: Bearer $ACCESS_TOKEN" \
  "https://www.googleapis.com/drive/v3/files/$FOLDER_ID?fields=name,id,capabilities")

echo "Folder info: $FOLDER_INFO"

# Try uploading directly to the folder
echo "Attempting to upload directly to folder..."
FOLDER_RESPONSE=$(curl -s -X POST -L \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -F "metadata={name:'$APK_NAME',parents:['$FOLDER_ID']};type=application/json;charset=UTF-8" \
  -F "file=@$APK_PATH;type=application/vnd.android.package-archive" \
  "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart")

echo "Folder upload response: $FOLDER_RESPONSE"

# Check if upload was successful
if [[ $FOLDER_RESPONSE == *"id"* ]]; then
    echo "Upload successful to folder!"
    echo "Response: $FOLDER_RESPONSE"

    # Clean up
    rm -f $SERVICE_ACCOUNT_FILE
    exit 0
else
    echo "Upload to folder failed, trying with root My Drive..."
fi

# Try uploading to root of My Drive as fallback
RESPONSE=$(curl -s -X POST -L \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -F "metadata={name:'$APK_NAME'};type=application/json;charset=UTF-8" \
  -F "file=@$APK_PATH;type=application/vnd.android.package-archive" \
  "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart")

# Check if upload was successful
if [[ $RESPONSE == *"id"* ]]; then
    echo "Upload successful to My Drive root!"
    echo "Response: $RESPONSE"

    # Clean up
    rm -f $SERVICE_ACCOUNT_FILE
    exit 0
else
    echo "Upload failed!"
    echo "Response: $RESPONSE"
    exit 1
fi
```

Make sure to replace `YOUR_FOLDER_ID` with your actual Google Drive folder ID.

## Step 9: Update codemagic.yaml

Create or update your `codemagic.yaml` file:

```yaml
workflows:
  android-release:
    name: Android Release
    max_build_duration: 60
    triggering:
      events:
        - push
      branch_patterns:
        - pattern: "main"
          include: true
    environment:
      flutter: stable
      groups:
        - SECRET
    scripts:
      - brew install jq python3
      - pip3 install pyjwt cryptography
      - flutter pub get
      - flutter build apk --release
      - bash upload_apk.sh
    artifacts:
      - build/app/outputs/flutter-apk/app-release.apk
```

## Step 10: Commit and Push

1. Make the upload script executable:

   ```bash
   chmod +x upload_apk.sh
   ```

2. Add the files to your repository:

   ```bash
   git add upload_apk.sh codemagic.yaml
   git commit -m "Add automatic APK upload to Google Drive"
   git push
   ```

3. Make sure to add `gcloud-service-key.json` to your `.gitignore` file to prevent accidentally committing it.

## Step 11: Run the Workflow

1. Go to your Codemagic dashboard
2. Select your project
3. Run the workflow manually or push to your main branch to trigger it automatically

## How It Works

1. Codemagic builds your Flutter APK
2. The script creates a temporary service account key file from your environment variable
3. It generates a JWT token and exchanges it for an OAuth access token
4. The script uploads the APK to your specified Google Drive folder
5. If successful, you'll see a link to the uploaded file in the build logs

## Troubleshooting

If you encounter issues:

1. **Permission errors**: Make sure you've shared the folder with the service account email
2. **API not enabled**: Verify the Drive API is enabled in your Google Cloud project
3. **Invalid folder ID**: Double-check the folder ID in your script
4. **Missing dependencies**: Ensure jq and Python JWT are installed correctly

## Security Considerations

- Keep your service account key secure and never commit it to your repository
- Use environment variables for sensitive information
- Consider using a more restrictive IAM role for your service account
- Regularly rotate your service account keys

## Additional Resources

- [Google Drive API Documentation](https://developers.google.com/drive/api/v3/about-sdk)
- [Codemagic Documentation](https://docs.codemagic.io/)
- [Flutter Documentation](https://flutter.dev/docs)
- [JWT Authentication](https://jwt.io/introduction/)

By following this guide, you'll have a fully automated system for uploading your app builds to Google Drive whenever you push changes to your repository. This saves time and ensures your team always has access to the latest builds.
