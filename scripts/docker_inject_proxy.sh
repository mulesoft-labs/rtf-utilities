# Constants
GRAVITY_BASH="gravity planet enter -- --notty /usr/bin/bash -- -c"
SYSTEM_NO_PROXY="kubernetes.default.svc,.local,0.0.0.0/0"


function inject_proxy_into_dockerd() {
    if [ -f $STATE_DIR/$FUNCNAME ]; then
        echo $SKIP_TEXT
        return 0
    fi

    if [ -z $1 ]; then
        echo "Skipped. HTTP proxy not configured"
        return 0
    fi

    echo "Injecting HTTP proxy into Docker daemon..."
    DOCKER_PROXY_CMD="cat > /etc/systemd/system/docker.service.d/http-proxy.conf <<EOF
[Service]
Environment=\"HTTP_PROXY=$1\" \"HTTPS_PROXY=$1\" \"NO_PROXY=$SYSTEM_NO_PROXY\"
EOF"
    $GRAVITY_BASH "$DOCKER_PROXY_CMD"
    gravity planet enter -- --notty  /usr/bin/systemctl -- daemon-reload
    gravity planet enter -- --notty  /usr/bin/systemctl -- restart docker

}


inject_proxy_into_dockerd $1