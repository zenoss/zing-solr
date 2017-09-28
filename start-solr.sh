#!/usr/bin/env bash
#
# This script is used to start Solr in a docker contaienr such that on receipt of
# SIGTERM the proper "solr stop" command is invoked to insure a clean shutdown of Solr
#
# TODO: we should try integrating this script with an 'official' docker image for solr
#       rather than our hand-rolled image
#
log () {
    echo $(date "+%y/%m/%d %H:%M:%S") "$1 $(basename $0): $2"
}

exitHandler() {
	log INFO "SIGTERM received; stopping solr ..."
	solr stop
}

# Register a signal handler that will initiate the proper shutdown
trap exitHandler SIGTERM

log INFO "Starting solr with the command 'solr start $*' "
solr start $* &

# The first wait returns when SIGTERM is received
wait

# The second wait returns when the solr child process has actually exited
wait
RC=$?

log INFO "Child exited"
exit $?