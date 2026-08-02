FROM node:20-slim

WORKDIR /app

COPY package.json ./
RUN npm install --omit=dev

COPY index.js prompt.js utils.js ./
COPY providers ./providers

ENV PORT=8080
EXPOSE 8080

CMD ["node", "index.js"]
