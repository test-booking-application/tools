#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: ./update_token.sh <NEW_GITHUB_TOKEN>"
  exit 1
fi

TOKEN=$1
ENCODED_TOKEN=$(echo -n "$TOKEN" | base64)

echo "Updating jenkins-credentials with new GitHub token..."
kubectl patch secret jenkins-credentials -n jenkins -p "{\"data\":{\"github-token\":\"$ENCODED_TOKEN\"}}"

echo "Restarting Jenkins pod to pick up changes..."
kubectl delete pod jenkins-0 -n jenkins

echo "Done! Jenkins is restarting. Please wait a minute for it to come back up."
