#!/bin/bash

DOCKERHUB_USER="internundip"
REPO_NAME="website-eduko"
AUTH_RESPONSE=$(curl -s -H "Content-Type: application/json" -X POST -d '{"username": "'${DOCKERHUB_USER}'", "password": "'${DOCKER_PAT}'"}' https://hub.docker.com/v2/users/login/)
if [ -z "$AUTH_RESPONSE" ]; then
    echo "Failed to authenticate with Docker Hub. Please check your credentials."
    exit 1
fi
if echo "$AUTH_RESPONSE" | jq -e '.token' >/dev/null 2>&1; then
    echo "Authentication successful."
else
    echo "Authentication failed. Please check your Docker Hub credentials."
    exit 1
fi

TOKEN=$(echo "$AUTH_RESPONSE" | jq -r .token)
if [ -z "$TOKEN" ]; then
    echo "Failed to retrieve token from Docker Hub authentication response."
    exit 1
fi

LATEST_TAG_NUMBER=$(curl -s -H "Authorization: JWT $TOKEN" "https://hub.docker.com/v2/repositories/${DOCKERHUB_USER}/${REPO_NAME}/tags/?page_size=2&ordering=last_updated" | jq -r '.results[] | select(.name != "latest") | .name')
if [ -z "$LATEST_TAG_NUMBER" ]; then
    echo "No tags found for repository ${DOCKERHUB_USER}/${REPO_NAME}. Exiting."
    exit 1
fi

NEXT_TAG=$((LATEST_TAG_NUMBER + 1))
echo "Next tag number is: $NEXT_TAG"

echo "Logging in to Docker Hub..."
echo ${DOCKER_PAT} | docker login -u ${DOCKERHUB_USER} --password-stdin || {
    echo "Docker login failed. Please check your credentials."
    exit 1
}

echo "Building Docker image with tag: $NEXT_TAG"
docker build -t website-eduko:$NEXT_TAG .

echo "Tagging Docker image for Docker Hub..."
docker tag website-eduko:$NEXT_TAG internundip/website-eduko:$NEXT_TAG
docker tag website-eduko:$NEXT_TAG internundip/website-eduko:latest

echo "Pushing Docker image to Docker Hub..."
docker push internundip/website-eduko:$NEXT_TAG
docker push internundip/website-eduko:latest

echo "Docker image pushed successfully with tags: $NEXT_TAG and latest."
cd /opt/monitoring/terraform
git pull origin main
cd ansible

echo "Executing CI/CD pipeline to update web server with new Docker image..."
ansible-playbook -i inventory.ini cicd-playbook.yml --tags web_server_config

echo "[✓] CI/CD pipeline executed successfully. Web server updated with new Docker image."