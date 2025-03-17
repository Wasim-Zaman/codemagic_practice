#!/bin/bash

# Define variables
APK_PATH=build/app/outputs/flutter-apk/app-release.apk
FOLDER_ID="1PpiC7wAjovTSx7T4bb6LqETwvp1WQeJm" # Change this to your specific Drive folder ID
SERVICE_ACCOUNT_FILE="gcloud-service-key.json"

# Save the JSON key file from the environment variable
echo $GCLOUD_SERVICE_ACCOUNT_JSON | base64 --decode > $SERVICE_ACCOUNT_FILE

# Authenticate with Google Cloud
gcloud auth activate-service-account --key-file=$SERVICE_ACCOUNT_FILE

# Upload the APK
gcloud auth application-default print-access-token | \
  curl -X POST -L -H "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
  -F "metadata={name :'app-release.apk', parents : ['$FOLDER_ID']};type=application/json;charset=UTF-8" \
  -F "file=@$APK_PATH;type=application/vnd.android.package-archive" \
  "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart"

# Clean up
rm -f $SERVICE_ACCOUNT_FILE