FROM node:current-alpine3.19
RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app
COPY package.json .
RUN npm install
COPY . /usr/src/app
EXPOSE 8080
CMD ["npm", "start"]
