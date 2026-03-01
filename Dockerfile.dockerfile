# 1. Use a pre-built server image that has PHP 8.2 and Nginx ready to go
FROM webdevops/php-nginx:8.2-alpine

# 2. Tell the server that Laravel's public folder is the main entry point
ENV WEB_DOCUMENT_ROOT=/app/public

# 3. Move into the app folder
WORKDIR /app

# 4. Copy all your Laravel code from GitHub into the server
COPY . .

# 5. Install all Laravel dependencies (skipping developer tools)
RUN composer install --no-interaction --optimize-autoloader --no-dev

# 6. Give the server permission to read and write files (like logs/cache)
RUN chown -R application:application .