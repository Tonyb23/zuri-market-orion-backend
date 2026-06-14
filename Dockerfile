# Use an official Node.js runtime as a parent image
FROM node:18-alpine

# Set the working directory in the container
WORKDIR /app

# Copy package.json and package-lock.json to the working directory of the container
COPY package*.json ./

# Install dependencies - exactly what is in package-lock.json to ensure consistent installs
RUN npm ci --only=production

# Copy the rest of the application code to the working directory of the container
COPY . .

# The port the app runs on
EXPOSE 5000

# Start the application
CMD ["node", "server.js"]