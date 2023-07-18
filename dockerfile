FROM node:18-alpine as pnpm_base

WORKDIR /app
RUN npm i --global --no-update-notifier --no-fund pnpm@7
RUN apk add --no-cache g++ make py3-pip libc6-compat

# STAGE 2: fetch deps into the pnpm store
FROM pnpm_base as fetched_deps
WORKDIR /app
ENV NODE_ENV production
COPY pnpm-lock.yaml ./
RUN pnpm config set store-dir /workdir/.pnpm-store
RUN pnpm fetch

# STAGE 3: Copy the application code and install all deps from cache into the application
FROM fetched_deps as with_all_deps
COPY . ./
RUN pnpm install --offline

# STAGE 4: Build the NextJS app
FROM with_all_deps as builder
RUN pnpm build
RUN pnpm --filter=chat-ai deploy pruned --prod

# STAGE 5: Create a clean production image - only take pruned assets
FROM node:18-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
RUN addgroup --system --gid 1001 app
RUN adduser --system --uid 1001 app
USER app

COPY --chown=app:app --from=builder /app/.next/standalone ./
#COPY --chown=app:app --from=builder /app/public ./public
COPY --chown=app:app --from=builder /app/.next/static ./.next/static

ENV PORT 3000
EXPOSE 3000

CMD ["node", "server.js"]