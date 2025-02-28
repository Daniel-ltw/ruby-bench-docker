#!/bin/bash

RAILS_VERSION=$1
API_NAME=$2
API_PASSWORD=$3
PREPARED_STATEMENTS=$4
PATTERNS=$5

mkdir -p $HOME/logs/rails/releases
DATETIME=$(date -d "today" +"%Y%m%d%H%M")
exec &>> $HOME/logs/rails/releases/$DATETIME-$RAILS_VERSION.log

echo
echo
echo
echo
echo "-------------- $(date)"

set -x

docker pull rubybench/rails_releases

docker run --name postgres -d postgres:9.6 -c shared_buffers=500MB -c fsync=off -c full_page_writes=off
docker run --name mysql -e "MYSQL_ALLOW_EMPTY_PASSWORD=yes" -d mysql:5.6.24
docker run --name redis -d redis:2.8.19

docker run --rm \
  --link postgres:postgres \
  --link mysql:mysql \
  --link redis:redis \
  -e "RAILS_VERSION=$RAILS_VERSION" \
  -e "API_NAME=$API_NAME" \
  -e "API_PASSWORD=$API_PASSWORD" \
  -e "MYSQL2_PREPARED_STATEMENTS=$PREPARED_STATEMENTS" \
  -e "INCLUDE_PATTERNS=$PATTERNS" \
  rubybench/rails_releases

docker stop postgres mysql redis
docker rm -v postgres mysql redis
