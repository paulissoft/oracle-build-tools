#!/bin/bash -eu

# See https://tm-apex.blogspot.com/2022/06/running-apex-in-docker-container.html

function init {
    CURDIR=$(cd $(dirname $0) && pwd)

    if [ -f $CURDIR/.env ]
    then
        source $CURDIR/.env
    fi

    echo ${DB_CONTAINER:=db-container}
    echo ${ORDS_CONTAINER:=ords}
    echo ${NETWORK:=demo-network}
    echo ${VOLUME:=db-demo-volume}
    echo ${ORDS_DIR:=~/opt/oracle/ords}
    echo ${ORACLE_HOSTNAME:=database}
    echo ${ORACLE_PORT:=1521}
    echo ${APEX_PORT:=8181}

    if [ ! -f $CURDIR/.env ]
    then
        cat > $CURDIR/.env <<EOF
DB_CONTAINER=$DB_CONTAINER
ORDS_CONTAINER=$ORDS_CONTAINER
NETWORK=$NETWORK
VOLUME=$VOLUME
ORDS_DIR=$ORDS_DIR
ORACLE_HOSTNAME=$ORACLE_HOSTNAME
ORACLE_PORT=$ORACLE_PORT
APEX_PORT=$APEX_PORT
EOF
    fi

    export DB_CONTAINER ORDS_CONTAINER NETWORK VOLUME ORDS_DIR ORACLE_HOSTNAME ORACLE_PORT APEX_PORT

    printenv ORACLE_PWD 1>/dev/null 2>&1 || read -p "Oracle password? " ORACLE_PWD
    export ORACLE_PWD
    test -d $ORDS_DIR || mkdir -p $ORDS_DIR
    echo "CONN_STRING=sys/${ORACLE_PWD}@${ORACLE_HOSTNAME}:${ORACLE_PORT}/XEPDB1" > $ORDS_DIR/conn_string.txt

    # Mac M1 & M2 architectures
    if which colima
    then
        if ! colima list | grep Running
        then
            colima start -c 4 -m 12 -a x86_64
        fi
    fi

    docker network ls | grep $NETWORK || docker network create $NETWORK
    docker network ls
    docker volume ls | grep $VOLUME || docker volume create $VOLUME
    docker volume ls
    
    docker login container-registry.oracle.com
}

function setup {
    # Oracle XE
    docker pull container-registry.oracle.com/database/express:latest
    docker image tag container-registry.oracle.com/database/express:latest oracle-xe-21.3
#    docker rmi container-registry.oracle.com/database/express:latest
    docker images

    # ORDS and APEX
    docker pull container-registry.oracle.com/database/ords:latest
    docker image tag container-registry.oracle.com/database/ords:latest ords-21.4
#    docker rmi container-registry.oracle.com/database/ords:latest
}

function run_oracle_xe {
    docker run -d --name db-container \
           -p 1521:${ORACLE_PORT} \
           -e ORACLE_PWD=${ORACLE_PWD} \
           -v $VOLUME:/opt/oracle/oradata \
           --network=$NETWORK \
           --hostname $ORACLE_HOSTNAME \
           oracle-xe-21.3
}

function run_ords {
    docker run -d --name ords --network=$NETWORK -p 8181:${APEX_PORT} -v $ORDS_DIR:/opt/oracle/variables ords-21.4
    docker exec -it ords tail -f /tmp/install_container.log
    open http://localhost:${APEX_PORT}/ords/
}

function main {
    ! printenv DEBUG 1>/dev/null 2>&1 || set -x
    if [ $# -eq 0 ]
    then
        echo "Usage: $0 [ docker | docker-compose [OPTIONS] COMMAND ]" 1>&2
        exit 1
    else
        init
        case "$1" in
            "docker")
                # Use Docker to start all
                setup
                run_oracle_xe
                run_ords
                ;;
            "docker-compose")
                shift
                docker-compose -f $CURDIR/oracle-xe-apex.yaml "$@"
                ;;
        esac
    fi
}

main "$@"
