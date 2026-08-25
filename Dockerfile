# ========== UltraContext API - Production Dockerfile ==========
# Build context = root monorepo
# Runtime: tsx (packages export .ts trực tiếp, không có dist)

FROM node:22-alpine AS base
RUN corepack enable && corepack prepare pnpm@10.28.1 --activate
WORKDIR /app

# ---------- 1. Dependencies (cache layer) ----------
FROM base AS deps
# Copy toàn bộ manifest cần thiết cho workspace resolve
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY apps/api/package.json ./apps/api/
COPY apps/mcp-server/package.json ./apps/mcp-server/
COPY packages/core/package.json ./packages/core/
COPY packages/storage/package.json ./packages/storage/
COPY packages/parsers/package.json ./packages/parsers/
# Nếu js-sdk cũng bị depend gián tiếp thì copy thêm:
# COPY apps/js-sdk/package.json ./apps/js-sdk/

# Cài đầy đủ (devDeps cũng cần vì tsx + typescript runtime)
RUN pnpm install --frozen-lockfile

# ---------- 2. Source ----------
FROM base AS runner
ENV NODE_ENV=production
WORKDIR /app

# Lấy node_modules đã resolve workspace
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/apps/api/node_modules ./apps/api/node_modules
COPY --from=deps /app/apps/mcp-server/node_modules ./apps/mcp-server/node_modules
COPY --from=deps /app/packages ./packages

# Copy source thật sự cần chạy
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY apps/api ./apps/api
COPY apps/mcp-server ./apps/mcp-server
COPY packages/core ./packages/core
COPY packages/storage ./packages/storage
# parsers không bắt buộc cho API, nhưng an toàn thì copy luôn
COPY packages/parsers ./packages/parsers

WORKDIR /app/apps/api

# tsx phải có sẵn (đã nằm trong node_modules nhờ install ở deps)
EXPOSE 8787
CMD ["npx", "tsx", "src/server.ts"]
