FROM registry.redhat.io/rhel9/rhel-bootc:9.4
# FROM quay.io/centos-bootc/centos-bootc:stream9

ARG FALCON_CID

COPY assets /tmp/assets

RUN \
  # install falcon sensor
  rpm --import /tmp/assets/*.gpg && \
  dnf -y install /tmp/assets/*.rpm && \
  # /opt is not writable on image-mode RHEL so move to /var/opt/CrowdStrike
  mv /opt/CrowdStrike /var/opt && \
  ln -s /var/opt/CrowdStrike /opt/CrowdStrike && \
  # set selinux contexts to match what they would be inside of /opt/CrowdStrike
  dnf -y install policycoreutils-devel && \
  semanage fcontext -a -t usr_t "/var/opt/CrowdStrike(/.*)?" && \
  semanage fcontext -a -N -t  lib_t "/var/opt/CrowdStrike/.*\.so(\.[^/]*)*" && \
  # configure and enable sensor
  /opt/CrowdStrike/falconctl -s --cid=$FALCON_CID && \
  systemctl enable falcon-sensor && \
  # debug tools
  dnf -y install audit & \
  # cleanup
  dnf clean all
