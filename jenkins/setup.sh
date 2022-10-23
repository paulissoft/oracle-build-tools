#!/bin/bash -eu

# Environment variables used:
# - DEBUG: for executing set -x
# - JENKINS_CONTROLLER: do we setup a Jenkins Docker controller or not (0=false; 1=true)? On Linux no, else yes.
# - NFS_SERVER_VOLUME: the NFS server Docker volume or bind host path. Defaults to a path (~/nfs/jenkins/home).
# - JENKINS: will we set up containers necessary for Jenkins (0=false; 1=true)? Defaults to no.
# - NFS: will we set up NFS (0=false; 1=true)? Defaults to yes.
# - CLEANUP: do we clean up Docker volumes and the NFS_SERVER_VOLUME host path (0=false; 1=true)? Defaults to no.

init() {
    ! printenv DEBUG 1>/dev/null || set -x

    if [ $JENKINS -ne 0 ]
    then
        # The docker-compose.yml is the common file.
        docker_compose_files="-f docker-compose.yml"
        if ! printenv JENKINS_CONTROLLER 1>/dev/null
        then
            case $(uname) in
                Linux)
                    # Assume that Jenkins is installed as a service 
                    JENKINS_CONTROLLER=0
                    ;;
                *)
                    JENKINS_CONTROLLER=1
                    ;;
            esac
        fi
        test "$JENKINS_CONTROLLER" -eq 0 || docker_compose_files="$docker_compose_files -f docker-compose-jenkins-controller.yml"
    else
        docker_compose_files=
    fi
    
    if [ $NFS -ne 0 ]
    then
        if ! printenv NFS_SERVER_VOLUME 1>/dev/null
        then
            export NFS_SERVER_VOLUME=~/nfs/jenkins/home
        fi

        # Is NFS_SERVER_VOLUME a Docker volume or a path?
        case "$NFS_SERVER_VOLUME" in
            ~* | */*)
                NFS_SERVER_VOLUME_TYPE=bind
                ;;
            *)
                NFS_SERVER_VOLUME_TYPE=volume
                ;;
        esac

        if [ "$NFS_SERVER_VOLUME_TYPE" = "bind" ]
        then
            test "$CLEANUP" -eq 0 || test ! -d "$NFS_SERVER_VOLUME" || rm -fr "$NFS_SERVER_VOLUME"
    
            # Create the shared directory as well as the Maven .m2/repository directory and the workspace
            for d in $NFS_SERVER_VOLUME $NFS_SERVER_VOLUME/repository $NFS_SERVER_VOLUME/workspace
            do
                test -d $d || mkdir -p $d
                chmod -R 755 $d
            done
            # make NFS_SERVER_VOLUME absolute
            NFS_SERVER_VOLUME=$(cd $NFS_SERVER_VOLUME && pwd)
        fi

        # Both NFS_SERVER_VOLUME_TYPE and NFS_SERVER_VOLUME will be used in docker-compose-jenkins-nfs-server.yml
        export NFS_SERVER_VOLUME_TYPE NFS_SERVER_VOLUME
        
        docker_compose_files="$docker_compose_files -f docker-compose-jenkins-nfs-server.yml -f docker-compose-jenkins-nfs-client.yml"
    fi
}

set_lib_module_dir()
{
    if test "$(uname)" = "Darwin"
    then
        declare dir=./.initrd
        test -d $dir || mkdir -p $dir
        # make dir absolute
        dir=$(cd $dir && pwd)
        test -d $dir/lib/modules || (cd $dir && gzip -dc /Applications/Docker.app/Contents//Resources/linuxkit/initrd.img | cpio -id 'lib/modules')
        LIB_MODULES_DIR=$dir/lib/modules
    else
        LIB_MODULES_DIR=/lib/modules               
    fi
    export LIB_MODULES_DIR
}

build() {
    if [ $NFS -ne 0 ]
    then
        set_lib_module_dir
    fi
    
    # See https://serverfault.com/questions/789601/check-is-container-service-running-with-docker-compose
    
    # common service
    if [ $JENKINS -ne 0 ]
    then
        service=jenkins-docker
    elif [ $NFS -ne 0 ]
    then
        service=jenkins-nfs-server
    else
        echo "Either JENKINS or NFS must be true" 1>&2
        exit 1
    fi
    
    if [ -z `docker-compose $docker_compose_files ps -q $service` ] || [ -z `docker ps -q --no-trunc | grep $(docker-compose $docker_compose_files ps -q $service)` ]
    then
        echo "Service $service is not running."
    else
        echo "Service $service is running: shutting it down."
        docker-compose $docker_compose_files down --remove-orphans
    fi

    docker-compose $docker_compose_files build
}

start() {
    if [ $CLEANUP -ne 0 ]
    then
        # Remove the volumes since they may have been created with the wrong JENKINS_NFS_SERVER variables
        set -- jenkins-m2-repository jenkins-agent-workspace
        for v
        do
            if docker volume ls | grep $v
            then
                docker volume rm $v || true
            fi
        done
    fi

    ( set -x; docker-compose $docker_compose_files $docker_compose_command_and_options )

    # $curdir/show_volumes.sh
}

# main

curdir=$(dirname $0)
if [ $# -ge 1 ]
then
    docker_compose_command_and_options="$@"
else
    docker_compose_command_and_options="up -d"
fi

echo "JENKINS: ${JENKINS:=0}"
echo "NFS: ${NFS:=1}"
echo "CLEANUP: ${CLEANUP:=0}"

init
build
start
