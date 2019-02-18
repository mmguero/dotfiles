#!/bin/bash

while true; do echo "HTTP/1.1 200 OK\n\n" |nc -l -p 80 |egrep -v "Accept" |egrep -v "Content-Length" |egrep -v "Host" |egrep -vi "cache" >> log.txt; done

