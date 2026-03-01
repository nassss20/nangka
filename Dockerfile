# Stage 1: Build the Flutter Web App using a pre-configured Flutter image
FROM ghcr.io/cirruslabs/flutter:stable AS build-env

# Set the working directory inside the container
WORKDIR /app

# Copy all your project files into the container
COPY . .

# Get Dart dependencies and build the web app
RUN flutter pub get
RUN flutter build web

# Stage 2: Serve the app using Nginx
FROM nginx:alpine

# Copy the finished web files from Stage 1 into the Nginx web server
COPY --from=build-env /app/build/web /usr/share/nginx/html

# Expose port 80 so Render can route traffic to it
EXPOSE 80

# Start the server
CMD ["nginx", "-g", "daemon off;"]