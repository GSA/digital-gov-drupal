#!/bin/bash


echo "Allowing internet access from '${deploy_space}'..."

space_current=$(cf spaces | grep $(terraform workspace show))

cf target -s ${deploy_space}

cf bind-security-group public_networks_egress ${org} --space ${deploy_space}

cf target -s ${space_current}