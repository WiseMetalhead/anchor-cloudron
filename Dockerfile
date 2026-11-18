FROM cloudron/base:6.0.1@sha256:7b1e729960c3ca312d26e886917ba89483241bba0219ff292858e10d9d5768ee AS node-base

ARG NODE_VERSION=26.13.1
ARG NODE_SHA256=5c063e46bab0fbc1c17cc445d7ff129cbdcd0471be6ed83b6ab864f8143bc864

RUN curl -fsSLO "https://nodejs.org/download/release/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" && \
    echo "${NODE_SHA256}  node-v${NODE_VERSION}-linux-x64.tar.xz" | sha256sum --check --strict && \
    mkdir -p /usr/local/node && \
    tar -xJf "node-v${NODE_VERSION}-linux-x64.tar.xz" --strip-components=1 -C /usr/local/node && \
    rm "node-v${NODE_VERSION}-linux-x64.tar.xz"

ENV PATH=/usr/local/node/bin:$PATH

FROM node-base AS build

ARG PNPM_VERSION=12.16.1
RUN npm install --global "pnpm@${PNPM_VERSION}"

# renovate: datasource=github-releases depName=zhfahim/anchor versioning=semver extractVersion=^v(?<version>.+)$
ARG ANCHOR_VERSION=0.18.1

RUN mkdir -p /app/build && \
    curl -fsSL "https://github.com/ZhFahim/anchor/archive/refs/tags/v${ANCHOR_VERSION}.tar.gz" \
      | tar -xz -C /app/build --strip-components=1 -f -

WORKDIR /app/build/server
RUN pnpm install --frozen-lockfile && \
    pnpm prisma generate && \
    pnpm build && \
    if [ -d src/generated ]; then mkdir -p dist/src && cp -R src/generated dist/src/; fi && \
    pnpm prune --prod

WORKDIR /app/build/web
ENV NEXT_TELEMETRY_DISABLED=1
ENV SERVER_URL=http://127.0.0.1:3001
RUN pnpm install --frozen-lockfile && pnpm build

FROM node-base AS final

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PATH=/usr/local/node/bin:$PATH

RUN mkdir -p /app/code/server /app/code/web /app/pkg && \
    sed -e 's,^logfile=.*$,logfile=/run/supervisord.log,' \
        -e 's,^pidfile=.*$,pidfile=/run/supervisord.pid,' \
        -i /etc/supervisor/supervisord.conf

COPY --from=build /app/build/server/dist /app/code/server/dist
COPY --from=build /app/build/server/node_modules /app/code/server/node_modules
COPY --from=build /app/build/server/prisma /app/code/server/prisma
COPY --from=build /app/build/server/package.json /app/code/server/package.json
COPY --from=build /app/build/server/prisma.config.ts /app/code/server/prisma.config.ts

COPY --from=build /app/build/web/.next/standalone /app/code/web
COPY --from=build /app/build/web/.next/static /app/code/web/.next/static
COPY --from=build /app/build/web/public /app/code/web/public

COPY supervisor/anchor.conf /etc/supervisor/conf.d/anchor.conf
COPY start.sh /app/pkg/start.sh
COPY LICENSE /app/pkg/LICENSE

WORKDIR /app/code
EXPOSE 3000
CMD [ "/app/pkg/start.sh" ]
