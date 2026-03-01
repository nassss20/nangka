# Stage 1: Build the Flutter Web App
FROM debian:latest AS build-env

# Install necessary dependencies (outdated packages removed)
RUN apt-get update && apt-get install -y curl git wget unzip gdb libstdc++6 libglu1-mesa fonts-droid-fallback python3 xz-utils
RUN apt-get clean

# Clone the Flutter repo
RUN git clone https://github.com/flutter/flutter.git /usr/local/flutter
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Run flutter doctor
RUN flutter doctor -v
RUN flutter channel stable
RUN flutter upgrade

# Copy your app code into the container
WORKDIR /app
COPY . .

# Get Dart dependencies and build the web app
RUN flutter pub get
RUN flutter build web

# Stage 2: Serve the app using Nginx
FROM nginx:alpine

# Copy the built web files from Stage 1 into the Nginx server
COPY --from=build-env /app/build/web /usr/share/nginx/html

# Expose port 80 for Render
EXPOSE 80

# Start the server
CMD ["nginx", "-g", "daemon off;"]