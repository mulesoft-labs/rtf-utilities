#!/bin/bash
set -eo pipefail

RED='\033[0;31m'
NC='\033[0m' # No Color
GREEN='\033[0;32m'

CONTROL_PLANE=${1:-us}
case "$CONTROL_PLANE" in
    us*)
        CP_SUFFIX=""
        AMQP_EP="transport-layer.prod.cloudhub.io"
        HELM_EP="worker-cloud-helm-prod.s3.amazonaws.com"
        EX_EP="exchange2-asset-manager-kprod.s3.amazonaws.com"
        ECR_EP="ecr.us-east-1.amazonaws.com 494141260463.dkr.ecr.us-east-1.amazonaws.com"
        STARPORT_EP="prod-us-east-1-starport-layer-bucket.s3.amazonaws.com"
        LUMBERJACK_EP="dias-ingestor-nginx.prod.cloudhub.io"
        ;;
    eu*)
        CP_SUFFIX="-eu"
        AMQP_EP="transport-layer.prod-eu.msap.io"
        HELM_EP="worker-cloud-helm-prod-eu-rt.s3.amazonaws.com worker-cloud-helm-prod-eu-rt.s3.eu-central-1.amazonaws.com"
        EX_EP="exchange2-asset-manager-kprod-eu.s3.amazonaws.com exchange2-asset-manager-kprod-eu.s3.eu-central-1.amazonaws.com"
        ECR_EP="ecr.eu-central-1.amazonaws.com 494141260463.dkr.ecr.eu-central-1.amazonaws.com"
        STARPORT_EP="prod-eu-central-1-starport-layer-bucket.s3.amazonaws.com prod-eu-central-1-starport-layer-bucket.s3.eu-central-1.amazonaws.com"
        LUMBERJACK_EP="dias-ingestor-nginx.prod-eu.msap.io"
esac

BASE_DIR=/opt/anypoint/runtimefabric
NC_OPTS="-zw 5"
HTTPS_ENDPOINTS="anypoint.mulesoft.com kubernetes-charts.storage.googleapis.com \
docker-images-prod.s3.amazonaws.com $AMQP_EP $HELM_EP \
$EX_EP $ECR_EP $STARPORT_EP \
runtime-fabric${CP_SUFFIX}.s3.amazonaws.com"
SOCKS5_ENDPOINTS="$LUMBERJACK_EP"

function load_environment {
    CURRENT_STEP=$FUNCNAME
    if [ -f $BASE_DIR/env ]; then
        . $BASE_DIR/env
    fi

    if [ -z "$RTF_HTTP_PROXY" ]; then
        RTF_HTTP_PROXY=${HTTP_PROXY:-}
    fi

    if [ -z "$RTF_NO_PROXY" ]; then
        RTF_NO_PROXY=${NO_PROXY:-}
    fi
}

function check_nc() {
    set +e
    if ! [ -x "$(command -v nc)" ]; then
        set -e
        echo "Installing ncat..."
        yum install -q -y nc
        set +e
    fi
}

function check_ntp() {
    #disable exit-on-error
    set +e
    rpm -q chrony
    if [ $? != 0 ]; then
        echo "Installing chrony..."
        yum install -q -y chrony || true
    fi

    printf "Checking chrony sync status..."
    COUNT=0
    while :
    do
        chronyc tracking | grep -E 'Leap status\s+:\s+Normal'
        if [ "$?" == "0" ]; then
            echo -e "Connectivity to NTP servers [${GREEN}OK${NC}]"
            break
        fi
        let COUNT=COUNT+1
        if [ $COUNT -ge "3" ]; then
            echo "Error: chrony sync check failed $COUNT times, giving up."
            NTP_SERVERS=$(cat /etc/chrony.conf | grep -vxE '[[:blank:]]*([#;].*)?' | grep -Ei "server" | cut -d ' ' -f 2)
            echo -e "Connectivity to (NTP_SERVERS) [${RED}FAILED${NC}]"
            exit 1
        fi
        echo "Retrying in 30 seconds..."
        sleep 30
    done
}


echo -e "Testing connectivities..."
load_environment
check_nc
check_ntp

set +e

if [ -z $RTF_HTTP_PROXY ]; then
    NC_WITH_PROXY="nc"
else

    proto=$(echo $RTF_HTTP_PROXY | grep :// | sed -e's,^\(.*://\).*,\1,g')
    url="$(echo ${RTF_HTTP_PROXY/$proto/})"
    creds=$(echo $url | grep @ | cut -d@ -f1)
    proxy=$(echo $url | grep @ | cut -d@ -f2)

    echo "HTTP/HTTPS PROXY: $RTF_HTTP_PROXY"

    if [ -z $creds ]; then
        NC_WITH_PROXY="nc --proxy $proxy --proxy-type http"
    else
        NC_WITH_PROXY="nc --proxy $proxy --proxy-type http --proxy-auth $creds"
    fi
fi

if [ -z $RTF_MONITORING_PROXY ]; then
    NC_WITH_SOCKS5_PROXY="nc"
else
    proto=$(echo $RTF_MONITORING_PROXY | grep :// | sed -e's,^\(.*://\).*,\1,g')
    url=$(echo ${RTF_MONITORING_PROXY/$proto/})
    creds=$(echo $url | grep @ | cut -d@ -f1)
    proxy=$(echo $url | grep @ | cut -d@ -f2)

    echo "SOCKS5 PROXY: $RTF_MONITORING_PROXY"

    if [ -z $creds ]; then
        NC_WITH_SOCKS5_PROXY="nc --proxy $proxy --proxy-type socks5"
    else
        NC_WITH_SOCKS5_PROXY="nc --proxy $proxy --proxy-type socks5 --proxy-auth $creds"
    fi
   
fi


for ep in $HTTPS_ENDPOINTS
    do
      $NC_WITH_PROXY $NC_OPTS $ep 443
      if [ "$?" == "0" ]; then
        echo -e "Connectivity to $ep:443 [${GREEN}OK${NC}]"
      else
        echo -e "Connectivity to $ep:443 [${RED}FAILED${NC}]"
      fi
    done

for ep in $SOCKS5_ENDPOINTS
    do
      $NC_WITH_SOCKS5_PROXY $NC_OPTS $ep 5044
      if [ "$?" == "0" ]; then
        echo -e "Connectivity to $ep:5044 [${GREEN}OK${NC}]"
      else
        echo -e "Connectivity to $ep:5044 [${RED}FAILED${NC}]"
      fi
    done

set -e