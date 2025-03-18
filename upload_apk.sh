#!/bin/bash

# Define variables
APK_PATH=build/app/outputs/flutter-apk/app-release.apk
FOLDER_ID="123vfqwW7DjzfX0BQYZ77Q0BOnenaYF58"
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

# Debug: Print first few characters of the environment variable
echo "First 50 characters of GCLOUD_SERVICE_ACCOUNT_JSON:"
echo "${GCLOUD_SERVICE_ACCOUNT_JSON:0:50}"

# Save the JSON key file directly from the environment variable
# First, ensure the content starts with a curly brace
if [[ "$GCLOUD_SERVICE_ACCOUNT_JSON" != "{"* ]]; then
    echo "Error: Environment variable doesn't start with '{'. Content might be malformed."
    exit 1
fi

# Write the JSON content to file
printf '%s' "$GCLOUD_SERVICE_ACCOUNT_JSON" > $SERVICE_ACCOUNT_FILE

# Debug: Check the content of the service account file
echo "First 50 characters of service account file:"
head -c 50 $SERVICE_ACCOUNT_FILE
echo # New line

# Check if the service account file was created properly
if [ ! -s "$SERVICE_ACCOUNT_FILE" ]; then
    echo "Error: Service account file is empty or was not created properly"
    exit 1
fi

# Verify the JSON file format
if ! jq empty $SERVICE_ACCOUNT_FILE 2>/dev/null; then
    echo "Error: Invalid JSON format in service account file"
    exit 1
fi

# Install gcloud if needed
if ! command -v gcloud &> /dev/null; then
    echo "Installing Google Cloud SDK..."
    curl https://sdk.cloud.google.com | bash > /dev/null
    export PATH=$PATH:/root/google-cloud-sdk/bin
fi

# Debug: Print gcloud version
gcloud --version

# Authenticate with Google Cloud with verbose output
echo "Attempting to authenticate with service account..."
gcloud auth activate-service-account --key-file=$SERVICE_ACCOUNT_FILE --verbosity=debug

# Verify authentication
echo "Verifying authentication..."
gcloud auth list

# Get the current date for the APK name
CURRENT_DATE=$(date +"%Y-%m-%d_%H-%M")
APK_NAME="app-release_${CURRENT_DATE}.apk"

echo "Uploading APK as $APK_NAME to Google Drive folder $FOLDER_ID..."

# Get access token with error checking
ACCESS_TOKEN=$(gcloud auth print-access-token)
if [ -z "$ACCESS_TOKEN" ]; then
    echo "Error: Failed to get access token"
    exit 1
fi

# Upload the APK
RESPONSE=$(curl -s -X POST -L \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
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