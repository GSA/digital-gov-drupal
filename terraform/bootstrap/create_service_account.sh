#!/bin/bash

cf create-service cloud-gov-service-account space-deployer pipeline

orgname=$(cf target | grep org | awk '{print $NF}')
username=$(cf service-key pipeline pipeline-key | tail -n +3 | jq -r '.credentials.username')

for space in $(cf spaces | tail -n +4)
do
  cf set-space-role "${username}" "${orgname}" "${space}" SpaceDeveloper
done