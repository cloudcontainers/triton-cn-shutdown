#!/bin/bash
#
# CDDL HEADER START
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License (the "License").
# You may not use this file except in compliance with the License.
#
# A full copy of the text of the CDDL should have accompanied this
# source. A copy of the CDDL is also available via the Internet at
# http://www.illumos.org/license/CDDL.
# See the License for the specific language governing permissions
# and limitations under the License.
#
# When distributing Covered Code, include this CDDL HEADER in each
# file and include the License file at usr/src/OPENSOLARIS.LICENSE.
# If applicable, add the following below this CDDL HEADER, with the
# fields enclosed by brackets "[]" replaced with your own identifying
# information: Portions Copyright [yyyy] [name of copyright owner]
#
# CDDL HEADER END
#
#
# Copyright 2021 Cloudcontainers.net  All rights reserved.
# Use is subject to license terms.

set -o errexit
set -o pipefail
set -o nounset

. /lib/svc/share/smf_include.sh

# Check runlevel to prevent accidental shutdown of VM's when service is disabled
if who -r | grep -q -e 'run-level [56]'; then
        echo "Stopping instances as server is shutting down."
else
        echo "Not executing stop as server is not stopping."
        exit $SMF_EXIT_OK
fi

SVC_TIMEOUT=`svcprop -p stop/timeout_seconds $SMF_FMRI`
MAXSHUT=`expr 3 \* $SVC_TIMEOUT \/ 4` # 3/4 of time to zone shutdown

running_hvms() {
        vmadm list -p state=running | nawk -F: '{
                if ($2 == "KVM" || $2 == "BHYV"){
                        print $1
                }
        }'
}

running_lxs() {
        vmadm list -p state=running | nawk -F: '{
                if ($2 == "LX"){
                        print $1
                }
        }'
}

VMS=`running_hvms`
LXS=`running_lxs`

if [ -n "$VMS" ]; then
        WAITPIDS=""
        for VM in $VMS; do
                echo "Stopping $VM with timeout $MAXSHUT"
                vmadm stop "$VM" -t $MAXSHUT &
                WAITPIDS="$WAITPIDS $!"
        done
        for VM in $LXS; do
                echo "Stopping LX container $VM"
                zlogin "$VM" /sbin/init 0 < /dev/null &
        done
        wait $WAITPIDS
        echo "All HVMs stopped, restoring autoboot..."
        for VM in $VMS; do
                vmadm update $VM autoboot=true
        done
fi

exit $SMF_EXIT_OK

