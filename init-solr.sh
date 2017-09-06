#!/usr/bin/env bash
log () {
    echo $(date "+%y/%m/%d %H:%M:%S") "$1 init_solr.sh: $2"
}

# Ensure the solr chroot directory in Zookeeper is initialized
# This command will retry until the chroot directory exists
init_zk () {
    # ZK is comma-separated list of hosts.  e.g., zk1,zk2,zk3
    ZK_NODES=$1
    # ZK_CHROOT is the zk chroot for solr.  e.g., /solr
    ZK_CHROOT=$2
    while true; do
        # In the cases we want to check for, the makepath command will either
        #   1) Return 0, if it created the path, or
        #   2) Have a stderr message " KeeperErrorCode = NodeExists for /foobar"
        #      if the path already exists.
        # We need to grep the stderr from makepath in order to check for case (2);
        #   we would also like to log it in case of unexpected errors.  Redirect
        #   stderr into a tee process, which sends it to both stderr and stdout;
        #   pipe stdout into grep.
        server/scripts/cloud-scripts/zkcli.sh -z ${ZK_NODES} -cmd makepath ${ZK_CHROOT} \
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
    while ! /opt/solr/bin/solr healthcheck -c $COLLECTION; do
        if /opt/solr/bin/solr create -c $COLLECTION ; then
            log INFO "Created Solr collection \"$COLLECTION\""
        else
            log ERROR "Unable to create Solr collection \"$COLLECTION\""
            sleep 10
        fi
    done
    log INFO "Detected Solr collection \"$COLLECTION\""
}

# Some service require a delay before they start up in order to allow dependent
# services to start.
if [ -n "$BOOTSTRAP_SLEEP" ] ; then
	log INFO "sleep $BOOTSTRAP_SLEEP"
	sleep $BOOTSTRAP_SLEEP
fi

if [ -n "$ZK_HOST" ]; then
    # Stand-alone Zookeeper.
    # Split the ZK_HOST into nodes and chroot.
    #  e.g., zk1/solr -> (zk1, solr)
    split=(${ZK_HOST/\// })
    ZK_NODES=${split[0]}
    ZK_CHROOT=${split[1]}
else
    # Embedded Zookeeper.
    # Use local embedded zk node, use chroot from environment
    ZK_NODES=localhost:9983
fi


if [ -n "$ZK_CHROOT" ] ; then
    # zk chroot needs to be initialized
    if [ -z "$ZK_HOST" ] ; then
    # No ZK_HOST implies embedded zk; give solr a chance to start, then
        #  initializ zk chroot and collections
        (sleep 10; init_zk $ZK_NODES $ZK_CHROOT; init_collection metric-catalog) &
    else
        # Initialize zk chroot, give solr a chance to start up,
        #  then initialize collections as a background process
        init_zk $ZK_NODES /$ZK_CHROOT
        (sleep 10; init_collection metric-catalog) &
    fi
else
    # No zk chroot specified; just initialize collections
    (sleep 10; init_collection metric-catalog) &
fi  

# Start solr
exec "$@"

