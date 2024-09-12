FROM registry.redhat.io/rhel9/rhel-bootc:9.4
# FROM quay.io/centos-bootc/centos-bootc:stream9

ARG FALCON_CID

COPY assets /tmp/assets

RUN <<EOF
set -euxo pipefail

# install falcon sensor
rpm --import /tmp/assets/*.gpg
dnf -y install /tmp/assets/*.rpm

# /opt is not writable on image-mode RHEL so move to /var/opt/CrowdStrike
test -d /var/opt || mkdir /var/opt
mv /opt/CrowdStrike /var/opt/CrowdStrike
ln -s /var/opt/CrowdStrike /opt/CrowdStrike

# set selinux contexts to match what they would be inside of /opt/CrowdStrike
dnf -y install policycoreutils-devel
semanage fcontext -a -t usr_t "/var/opt/CrowdStrike(/.*)?"
semanage fcontext -a -N -t lib_t "/var/opt/CrowdStrike/.*\.so(\.[^/]*)*"

# workaround: allow service to restart briefly on failure (fatal issue where pidfile can't be created on first boot)
sed -i 's/\[Unit\]/\[Unit\]\nStartLimitIntervalSec=10/' /usr/lib/systemd/system/falcon-sensor.service
sed -i 's/\[Unit\]/\[Unit\]\nStartLimitBurst=3/' /usr/lib/systemd/system/falcon-sensor.service
sed -i 's/Restart=no/Restart=on-failure/' /usr/lib/systemd/system/falcon-sensor.service

# workaround: disable proxy (nonfatal issue where falcon logs "Could not retrieve DisableProxy value")
/opt/CrowdStrike/falconctl -s --apd=true

# configure and enable sensor
/opt/CrowdStrike/falconctl -s --cid=$FALCON_CID
systemctl enable falcon-sensor

# cleanup
dnf clean all
echo FALCON-BOOTC-COMPLETE

EOF
