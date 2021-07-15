# triton-cn-shutdown
Custom service to cleanly shut down VM's on a Triton compute node

Executes `vmadm stop` on all currently running KVM and Bhyve zones and then restores autoboot=true.

This is a workaround for the system/zones SMF service not stopping these processes cleanly.
See [svc-zones](https://github.com/joyent/illumos-joyent/blob/94ab2e105614e1e1bdbd8f66f306a26f56af2623/usr/src/cmd/zoneadm/svc-zones#L228-L262)
for details.

# Installation

Copy both `hvm-shutdown.sh` and `hvm-shutdown.xml` to the headnode and then distribute them to all compute nodes:

    sdc-oneachnode -c 'mkdir -p /opt/custom/svc/method/ /opt/custom/smf/'
    sdc-oneachnode -c -X -g hvm-shutdown.sh -d /opt/custom/svc/method/
    sdc-oneachnode -c -X -g hvm-shutdown.xml -d /opt/custom/smf/
    sdc-oneachnode -c 'svccfg import /opt/custom/smf/hvm-shutdown.xml'

# Implementation

During shutdown (`shutdown -i 5`) or restarts (`shutdown -i 6`) all SMF services are disabled in order.

The `opt/custom/svc/method/hvm-shutdown.sh` script lists all currently running zones and attempts to stop them cleanly.

For LX zones, this is accomplished using `zlogin {zone} init 0`.
For Bhyve and KVM this is done using `vmadm stop {zone}`, which (unfortunately) als changes the autoboot setting of the VM.
Because of this, the autoboot state is re-set once shutdown has been completed.

As stopping a KVM requires `vmadmd` to send the appropriate signals, the stop method needs to be executed while it is still running.
This is accomplished by having the hvm-shutdown service depend on it.

Similarly, the service depends on `system/zones` to ensure we have the chance to stop the zones before it gets a chance to do so.

