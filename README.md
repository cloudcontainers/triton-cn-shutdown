# triton-cn-shutdown
Custom service to cleanly shut down VM's on a Triton compute node

Executes `vmadm stop` on all currently running KVM and Bhyve zones and then restores autoboot=true.

This is a workaround for the system/zones SMF service not stopping these processes cleanly.
See [svc-zones](https://github.com/joyent/illumos-joyent/blob/94ab2e105614e1e1bdbd8f66f306a26f56af2623/usr/src/cmd/zoneadm/svc-zones#L228-L262)
for details.

