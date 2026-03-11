FROM node:20-slim

# Install ffmpeg, curl, ca-certificates and python3
RUN apt-get update && apt-get install -y \
    ffmpeg \
    curl \
    ca-certificates \
    python3 \
    --no-install-recommends \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install yt-dlp binary
RUN curl -L --cacert /etc/ssl/certs/ca-certificates.crt \
    https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp \
    -o /usr/local/bin/yt-dlp \
    && chmod a+rx /usr/local/bin/yt-dlp

WORKDIR /app

# Install dependencies first (layer cache)
COPY package*.json ./
RUN npm ci --omit=dev

# Copy server source
COPY . .

# Ensure downloads folder exists
RUN mkdir -p downloads

EXPOSE 3000

CMD ["node", "server.js"]
