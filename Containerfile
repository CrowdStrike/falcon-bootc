FROM registry.redhat.io/rhel9/rhel-bootc:9.6
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

# set selinux contexts to match what they would be inside of /opt/CrowdStrike,
# but only where the distro policy does not already do it. RHEL 10 ships a
# "/var/opt /opt" file context equivalency that RHEL 9 does not, and adding a
# rule that collides with an equivalency is an error, not a no-op, so these
# calls abort the build there. Comparing the two labels tests the outcome
# rather than the distro version, so it stays correct if RHEL 9 ever gains the
# same equivalency. matchpathcon is in the base image, so this runs before the
# install it guards.
if [ "$(matchpathcon -n /var/opt)" = "$(matchpathcon -n /opt)" ]; then
    echo "distro policy already labels /var/opt as /opt; skipping semanage"
else
    dnf -y install policycoreutils-devel
    semanage fcontext -a -t usr_t "/var/opt/CrowdStrike(/.*)?"
    semanage fcontext -a -N -t lib_t "/var/opt/CrowdStrike/.*\.so(\.[^/]*)*"
fi

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
