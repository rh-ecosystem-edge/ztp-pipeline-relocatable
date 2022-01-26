FROM registry.access.redhat.com/ubi8/nodejs-16:latest as builder
USER root

RUN dnf install -y jq
RUN curl --silent "https://api.github.com/repos/yarnpkg/yarn/releases/latest" | jq -r .tag_name | sed -e 's/^v//'> /yarn.version
RUN echo https://github.com/yarnpkg/yarn/releases/download/v$(cat /yarn.version)/yarn-$(cat /yarn.version)-1.noarch.rpm > /yarn.url
RUN curl -L --output /yarn.rpm $(cat /yarn.url)
RUN dnf install -y /yarn.rpm

WORKDIR /app
COPY ./frontend ./frontend
COPY ./backend ./backend
COPY ./package.json ./yarn.lock ./

RUN yarn clean
RUN yarn install
RUN yarn build

#############
FROM registry.access.redhat.com/ubi8/nodejs-16-minimal:latest
WORKDIR /app
ENV NODE_ENV production

COPY --from=builder /app/backend/build ./
COPY --from=builder /app/frontend/build ./client/

USER 1001
CMD ["node", "/app/backend/index.js"]
