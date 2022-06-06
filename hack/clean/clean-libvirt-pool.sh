#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -m

resourcesUsed=""

# get all disk and isos in use
getUsedResources() {
    for vm in $(kcli list vm -o json | jq -r .[].name); do
        # preserve ISO/iso used by existing vm's
        resourcesUsed=$(printf "%s|%s|${resourcesUsed}" "${vm}.ISO" "${vm}.iso")

        # preserve images used by existing vm's
        resourcesUsed=$(printf "%s|${resourcesUsed}" "$(kcli show vm ${vm} | grep image: | awk '{print $2}')")

        # preserve all disks used by existing vm's
        for disk in $(kcli show vm $vm | grep -E 'diskname:' | awk '{print $10}' | sed 's#\/var\/lib\/libvirt\/images\/##'); do
            resourcesUsed=$(printf "%s|${resourcesUsed}" "${disk}")
        done
    done
}

getUsedResources

# build a cmd that greps out the *used* resources
# ensuring that resources in toDelete are *unused*
resourcesGrep=$(echo $resourcesUsed | sed 's/.$//')
cmd=$(printf "ls /var/lib/libvirt/images | grep -Ev '%s'" ${resourcesGrep})
toDelete=$(eval $cmd)

# delete unused resources
for resource in $(echo $toDelete); do
    kcli delete disk --novm --yes ${resource}
done
