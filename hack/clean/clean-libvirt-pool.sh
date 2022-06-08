#!/usr/bin/env bash

set -o pipefail
set -m

if [ -n "${1}" ]; then

    resourcesUsed=""

    # get all disk and isos in use
    getUsedResources() {
        for vm in $(kcli list vm -o json | jq -r .[].name); do
            # preserve ISO/iso used by existing vm's
            resourcesUsed=$(printf "%s|${resourcesUsed}" "${vm}.ISO")

            # some vm's have a boot-ID iso - depending on how they were created
            resourcesUsed=$(printf "%s|${resourcesUsed}" "$(kcli show vm ${vm} | grep iso: | awk '{print $2}' | sed 's#\/var\/lib\/libvirt\/images\/##g')")

            # preserve images used by existing vm's
            resourcesUsed=$(printf "%s|${resourcesUsed}" "$(kcli show vm ${vm} | grep image: | awk '{print $2}' | sed 's#\/var\/lib\/libvirt\/images\/##g')")

            # preserve all disks used by existing vm's
            for disk in $(kcli show vm $vm | grep -E 'diskname:' | awk '{print $10}' | sed 's#\/var\/lib\/libvirt\/images\/##'); do
                resourcesUsed=$(printf "%s|${resourcesUsed}" "${disk}")
            done
        done
    }

    # get the resources
    getUsedResources

    # build a cmd that greps out the *used* resources
    # cmd has to guarantee resources in toDelete are *unused*
    # sanitize output by removing any trailing character
    # and also double || introduced by getUsedResources\
    # failing to do this will make cmd unusable and unreliable
    resourcesGrep=$(echo $resourcesUsed | sed 's/.$//' | sed 's/||/|/'g)
    cmd=$(printf "ls /var/lib/libvirt/images | grep -Ev '%s'" ${resourcesGrep})
    toDelete=$(eval $cmd)

    # dry-run will prompt the images to be deleted
    # now will wipe the pool
    case $1 in
        'dry-run')
            echo "############### ${0} dry-run"
            echo "############### resources in use - won't be deleted"
            echo $cmd
            echo ""

            echo "############### resources unused - will be delete"
            for resource in $(echo $toDelete); do
                echo $resource
            done
        ;;

        'now')
            for resource in $(echo $toDelete); do
            kcli delete disk --novm --yes ${resource}
            done
        ;;

        *)
        echo "Usage: [dry-run|now]"
        ;;
    esac
else
    echo "Usage: [dry-run|now]"
fi
