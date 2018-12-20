#IMAGE-NAME: willia4/sftp_volume
#IMAGE-VERSION: 1.3.5
FROM ubuntu:16.04

EXPOSE 22

RUN apt-get update
RUN apt-get -y install openssh-server grep vim

RUN mkdir -p /volumes/sftp_root && chown root:root /volumes/sftp_root && chmod 755 /volumes/sftp_root

VOLUME ["/volumes/ssh_keys"]
VOLUME ["/volumes/user"]

COPY docker_entrypoint.sh /
COPY ssh_config /etc/ssh/sshd_config

RUN chmod 555 /docker_entrypoint.sh

ENTRYPOINT ["/docker_entrypoint.sh"]