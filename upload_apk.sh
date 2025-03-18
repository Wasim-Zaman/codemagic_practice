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

# Write the JSON content to file
printf '%s' "$GCLOUD_SERVICE_ACCOUNT_JSON" > $SERVICE_ACCOUNT_FILE

# Debug: Check the content of the service account file
echo "First 50 characters of service account file:"
head -c 50 $SERVICE_ACCOUNT_FILE
echo # New line

# Install gcloud if needed
if ! command -v gcloud &> /dev/null; then
    echo "Installing Google Cloud SDK..."
    curl https://sdk.cloud.google.com | bash > /dev/null
    export PATH=$PATH:/root/google-cloud-sdk/bin
fi

# Debug: Print gcloud version
gcloud --version

# Set the OAuth scope before authentication
export CLOUDSDK_SCOPES="https://www.googleapis.com/auth/drive.file"

# Authenticate with Google Cloud
echo "Attempting to authenticate with service account..."
gcloud auth activate-service-account --key-file=$SERVICE_ACCOUNT_FILE

# Verify authentication
echo "Verifying authentication..."
gcloud auth list

# Get the current date for the APK name
CURRENT_DATE=$(date +"%Y-%m-%d_%H-%M")
APK_NAME="app-release_${CURRENT_DATE}.apk"

echo "Uploading APK as $APK_NAME to Google Drive folder $FOLDER_ID..."

# Get access token
ACCESS_TOKEN=$(curl -s -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer" \
  -d "assertion=$(python3 -c "
import json
import time
import base64

header = {'alg': 'RS256', 'typ': 'JWT'}
with open('$SERVICE_ACCOUNT_FILE') as f:
    sa = json.load(f)

claims = {
    'iss': sa['client_email'],
    'scope': 'https://www.googleapis.com/auth/drive.file',
    'aud': 'https://oauth2.googleapis.com/token',
    'exp': int(time.time()) + 3600,
    'iat': int(time.time())
}

import jwt
private_key = sa['private_key']
token = jwt.encode(claims, private_key, algorithm='RS256', headers=header)
print(token)
")" \
  https://oauth2.googleapis.com/token | jq -r .access_token)

if [ -z "$ACCESS_TOKEN" ]; then
    echo "Error: Failed to get access token"
    exit 1
fi

echo "Successfully obtained access token"

# Upload the APK
RESPONSE=$(curl -s -X POST -L \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
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