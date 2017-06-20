#!/usr/bin/env bash

log () {
    echo $(date "+%y/%m/%d %H:%M:%S") "$1 init_solr.sh: $2"
}

# Ensure the solr chroot directory in Zookeeper is initialized
# This command will retry until the chroot directory exists
init_zk () {
    if [ -z $ZK ] ; then
        log ERROR "ZK must be set to the Zookeeper host (e.g., zk)"
        exit 1
    elif [ -z $ZK_CHROOT ] ; then
        log ERROR "ZK_CHROOT must be set to the Zookeeper chroot for Solr (e.g., /solr)"
        exit 1
    fi
    while true; do
        # In the cases we want to check for, the makepath command will either
        #   1) Return 0, if it created the path, or
        #   2) Have a stderr message " KeeperErrorCode = NodeExists for /foobar"
        #      if the path already exists.
        # We need to grep the stderr from makepath in order to check for case (2);
        #   we would also like to log it in case of unexpected errors.  Redirect
        #   stderr into a tee process, which sends it to both stderr and stdout;
        #   pipe stdout into grep.
        server/scripts/cloud-scripts/zkcli.sh -z ${ZK} -cmd makepath ${ZK_CHROOT} \
            2> >(tee >(cat >&2)) | grep -q NodeExists
        # Capture the status of the two commands (zkcli and grep) for examination.
        status=(${PIPESTATUS[*]})
        if [ ${status[0]} == 0 ] ; then
            # makepath command succeeeded
            log INFO "Zookeeper chroot \"$ZK_CHROOT\" created"
            return 0
        elif [ ${status[1]} == 0 ] ; then
            # Found "NodeExists" in stderr
            log INFO "Ignored expected exception: Zookeeper chroot \"$ZK_CHROOT\" already exists"
            return 0
        else
            log ERROR "Unable to create Zookeeper chroot \"$ZK_CHROOT\""
            sleep 10
        fi
    done
    return 1
}

# Ensure that the indicated collection exists in Solr.
# This command will retry until the collection exists.
init_collection () {
    COLLECTION=$1
    while true ; do
    	/opt/solr/bin/solr healthcheck -c $COLLECTION && break
	    if ! /opt/solr/bin/solr create -c $COLLECTION ; then
            log ERROR "Unable to create Solr collection \"$COLLECTION\""
		    sleep 10
	    fi
    done
}


init_zk

# Initialize collection as a background process; it will complete after
#   Solr is up and running
(sleep 10 ; init_collection metric-catalog) &

exec "$@"

