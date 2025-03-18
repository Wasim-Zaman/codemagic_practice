#!/bin/bash

# Define variables
APK_PATH=build/app/outputs/flutter-apk/app-release.apk
FOLDER_ID="1CK55EUd0suHdmIm_cowoHI4LCzwczQfm"
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

# Get access token using JWT
ACCESS_TOKEN=$(python3 -c "
import json
import time
import jwt
import sys

try:
    with open('$SERVICE_ACCOUNT_FILE') as f:
        sa = json.load(f)
    
    # Create JWT claims with proper scope
    claims = {
        'iss': sa['client_email'],
        'scope': 'https://www.googleapis.com/auth/drive',
        'aud': 'https://oauth2.googleapis.com/token',
        'exp': int(time.time()) + 3600,
        'iat': int(time.time())
    }
    
    # Create JWT token
    token = jwt.encode(claims, sa['private_key'], algorithm='RS256')
    
    # Print token for debugging
    print(token)
except Exception as e:
    print(f'Error creating JWT: {str(e)}', file=sys.stderr)
    sys.exit(1)
" 2>&1)

if [[ $ACCESS_TOKEN == Error* ]]; then
    echo "Error generating JWT token: $ACCESS_TOKEN"
    exit 1
fi

echo "Successfully generated JWT token"

# Exchange JWT for access token
OAUTH_RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=$ACCESS_TOKEN" \
  https://oauth2.googleapis.com/token)

echo "OAuth response: $OAUTH_RESPONSE"

# Extract access token from response
ACCESS_TOKEN=$(echo $OAUTH_RESPONSE | jq -r '.access_token')

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" == "null" ]; then
    echo "Error: Failed to get access token"
    exit 1
fi

echo "Successfully obtained access token"

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