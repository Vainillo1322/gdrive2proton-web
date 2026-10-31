# gdrive2proton web edition
# Listens on $PORT (default 3000); keeps only the resume manifest and the
# Google OAuth client record under /data (set DATA_DIR to change it).
FROM golang:1.22 AS build
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -o /out/gdrive2proton .

FROM alpine:3.20
RUN apk add --no-cache ca-certificates
COPY --from=build /out/gdrive2proton /usr/local/bin/gdrive2proton
ENV PORT=3000 DATA_DIR=/data
VOLUME /data
EXPOSE 3000
CMD ["gdrive2proton"]
