#!/bin/bash


RED='\033[0;31m'
NC='\033[0m' # No Color
GREEN='\033[0;32m'
JOB_NO=$(openssl rand -hex 3)

sudo kubectl -n rtf create job --from=cronjob/registry-creds refresh-creds-$JOB_NO
sudo kubectl wait -n rtf job/refresh-creds-$JOB_NO --for=condition=complete --timeout=60s 

if [ "$?" == "0" ]; then
  echo -e "Job refresh-creds-$JOB_NO [${GREEN}completed${NC}]"
else
  echo -e "Job refresh-creds-$JOB_NO [${RED}failed${NC}]"
fi
sudo kubectl logs -n rtf -ljob-name=refresh-creds-$JOB_NO
sudo kubectl delete -nrtf job refresh-creds-$JOB_NO