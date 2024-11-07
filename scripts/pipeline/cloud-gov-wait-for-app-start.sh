#!/bin/bash

app_name=$1

while : ; do 
  app_status=$( cf app "${app_name}" | grep "#0" | awk '{print $2}' )
  if [ "${app_status}" == "running" ]; then
    break
  else
    echo "waiting for application to start..."
    sleep 2
  fi
done