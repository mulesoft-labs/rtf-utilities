#!/bin/bash

set -xe

# Update with your own values
USERNAME="your_user_name"
PASSWORD="your_password"
ORG_ID="b2ee7923-e6c7-4ca3-86a0-6304559b935d"
ENV_ID="6c3c3e41-e5a1-4423-81bc-8c05778bd9cb"
APP_NAME="demoapp"
JVM_ARGS="-XX:NativeMemoryTracking=detail"


TOKEN=$(curl -sS -X POST https://anypoint.mulesoft.com/accounts/login -H 'Content-Type: application/json' \
  -d '{"username": "'$USERNAME'","password": "'$PASSWORD'"}' | jq -r '.access_token')


ID=$(curl -sS https://anypoint.mulesoft.com/amc/application-manager/api/v2/organizations/$ORG_ID/environments/$ENV_ID/deployments \
  -H "Authorization: Bearer $TOKEN" | jq -r --arg APP_NAME "$APP_NAME" '.items | .[] | select(.name == $APP_NAME ) | .id ')

PATCH_REQUEST=$(curl -sS https://anypoint.mulesoft.com/amc/application-manager/api/v2/organizations/$ORG_ID/environments/$ENV_ID/deployments/$ID \
  -H "Authorization: Bearer $TOKEN" | jq -r --arg JVM_ARGS "$JVM_ARGS" '.target.deploymentSettings.jvm.args = $JVM_ARGS')

curl -X PATCH https://anypoint.mulesoft.com/amc/application-manager/api/v2/organizations/$ORG_ID/environments/$ENV_ID/deployments/$ID \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' --data-raw "$PATCH_REQUEST"