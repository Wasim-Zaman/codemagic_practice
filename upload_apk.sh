#!/bin/bash

# Define variables
APK_PATH=build/app/outputs/flutter-apk/app-release.apk
FOLDER_ID="123vfqwW7DjzfX0BQYZ77Q0BOnenaYF58" # Verify this is your actual Drive folder ID
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

# Save the JSON key file directly from the environment variable
# (assuming it's not base64 encoded in Codemagic)
echo "$GCLOUD_SERVICE_ACCOUNT_JSON" > $SERVICE_ACCOUNT_FILE

# Check if the service account file was created properly
if [ ! -s "$SERVICE_ACCOUNT_FILE" ]; then
    echo "Error: Service account file is empty or was not created properly"
    cat $SERVICE_ACCOUNT_FILE
    exit 1
fi

# Install gcloud if needed
if ! command -v gcloud &> /dev/null; then
    echo "Installing Google Cloud SDK..."
    curl https://sdk.cloud.google.com | bash > /dev/null
    export PATH=$PATH:/root/google-cloud-sdk/bin
fi

# Authenticate with Google Cloud
gcloud auth activate-service-account --key-file=$SERVICE_ACCOUNT_FILE

# Get the current date for the APK name
CURRENT_DATE=$(date +"%Y-%m-%d_%H-%M")
APK_NAME="app-release_${CURRENT_DATE}.apk"

echo "Uploading APK as $APK_NAME to Google Drive folder $FOLDER_ID..."

# Upload the APK
RESPONSE=$(curl -s -X POST -L \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -F "metadata={name:'$APK_NAME', parents:['$FOLDER_ID']};type=application/json;charset=UTF-8" \
  -F "file=@$APK_PATH;type=application/vnd.android.package-archive" \
  "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart")

# Check if upload was successful
if [[ $RESPONSE == *"id"* ]]; then
    echo "Upload successful!"
    echo "Response: $RESPONSE"
else
    echo "Upload failed!"
    echo "Response: $RESPONSE"
    exit 1
fi

# Clean up
rm -f $SERVICE_ACCOUNT_FILE