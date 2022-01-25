FROM registry.access.redhat.com/ubi8/nodejs-16:latest as frontend
USER root

RUN dnf install -y jq
RUN curl --silent "https://api.github.com/repos/yarnpkg/yarn/releases/latest" | jq -r .tag_name | sed -e 's/^v//'> /yarn.version
RUN echo https://github.com/yarnpkg/yarn/releases/download/v$(cat /yarn.version)/yarn-$(cat /yarn.version)-1.noarch.rpm > /yarn.url
RUN curl -L --output /yarn.rpm $(cat /yarn.url)
RUN dnf install -y /yarn.rpm

WORKDIR /app/frontend
COPY ./frontend/src ./src
COPY ./frontend/public ./public
COPY ./frontend/package.json ./frontend/yarn.lock ./
COPY ./frontend/tsconfig.json ./frontend/.eslintrc ./frontend/.prettierrc.yaml ./

RUN yarn install
RUN yarn build

#FROM registry.access.redhat.com/ubi8/nodejs-16-minimal:latest as backend
#WORKDIR /app/backend