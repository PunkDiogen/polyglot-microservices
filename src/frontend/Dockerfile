
FROM node:20-alpine AS builder
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm install --no-audit --no-fund
COPY . .
RUN npm run build

FROM node:20-alpine
RUN adduser -S appuser
WORKDIR /app
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/build ./build
COPY --from=builder /app/node_modules ./node_modules
RUN chown -R appuser /app
USER appuser
ENV NODE_ENV=production
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD node -e "fetch('http://localhost:3000').then(r=>{if(!r.ok)process.exit(1)}).catch(()=>process.exit(1))"

CMD ["node", "build/index.js"]
