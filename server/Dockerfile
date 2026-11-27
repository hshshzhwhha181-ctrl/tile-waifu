FROM node:24-alpine
WORKDIR /app
ENV NODE_ENV=production \
    PORT=8787 \
    HOST=0.0.0.0 \
    DB_PATH=/app/data/tilewaifu.db
COPY package.json server.mjs ./
COPY src ./src
RUN mkdir -p /app/data && chown -R node:node /app
USER node
VOLUME /app/data
EXPOSE 8787
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s CMD wget -qO- http://127.0.0.1:8787/api/v1/health || exit 1
CMD ["node", "server.mjs"]
