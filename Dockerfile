ARG REGISTRY_URL DOCKER_REPO_NAME NODE_VERSION

# Base image from 
FROM ${REGISTRY_URL}/${DOCKER_REPO_NAME}/node:${NODE_VERSION}

# Create app directory
WORKDIR /usr/src/app/

# Copy dependency definitions
COPY package.json ./package.json
COPY package-lock.json ./package-lock.json

RUN --mount=type=secret,id=npmrc,target=/root/.npmrc npm ci --ignore-scripts

# Get all the code needed to run the app
COPY . .

# Expose the port the app runs in
EXPOSE 4000

# Serve the app
CMD ["npm", "start"]