#!/bin/bash

function update_ssh_config {
	VAR_NAME=$1
	VAR_DEFAULT=$2

	VAR_VALUE=${!VAR_NAME}
	if [ -z "$VAR_VALUE" ]; then
		VAR_VALUE=$VAR_DEFAULT
	fi

	#VAR_VALUE=$(echo $VAR_VALUE | sed 's/\//\\\//g')
	sed -i "s/@@$VAR_NAME@@/$VAR_VALUE/g" /etc/ssh/sshd_config
}

if [ "$SFTP_CONTAINER_KEYS" == "CREATE" ]; then
	rm -f /volumes/ssh_keys/ssh_host_rsa_key > /dev/null
	rm -f /volumes/ssh_keys/ssh_host_dsa_key > /dev/null
	rm -f /volumes/ssh_keys/ssh_host_ecdsa_key > /dev/null
	rm -f /volumes/ssh_keys/ssh_host_ed25519_key > /dev/null

	rm -f /volumes/ssh_keys/ssh_host_rsa_key.pub > /dev/null
	rm -f /volumes/ssh_keys/ssh_host_dsa_key.pub > /dev/null
	rm -f /volumes/ssh_keys/ssh_host_ecdsa_key.pub > /dev/null
	rm -f /volumes/ssh_keys/ssh_host_ed25519_key.pub > /dev/null

	ssh-keygen -f /volumes/ssh_keys/ssh_host_rsa_key -N '' -t rsa -b 4096 > /dev/null
	ssh-keygen -f /volumes/ssh_keys/ssh_host_dsa_key -N '' -t dsa > /dev/null
	ssh-keygen -f /volumes/ssh_keys/ssh_host_ecdsa_key -N '' -t ecdsa -b 521 > /dev/null
	ssh-keygen -f /volumes/ssh_keys/ssh_host_ed25519_key -N '' -t ed25519 > /dev/null
fi

if [ ! -f /volumes/ssh_keys/ssh_host_rsa_key ]; then
	echo "The ssh_host_rsa_key does not exist and should be created. Consider setting SFTP_CONTAINER_KEYS=CREATE. This is an unrecoverable error."
	exit 2
fi

if [ ! -f /volumes/ssh_keys/ssh_host_dsa_key ]; then
	echo "The ssh_host_dsa_key does not exist and should be created. Consider setting SFTP_CONTAINER_KEYS=CREATE. This is an unrecoverable error."
	exit 2
fi

if [ ! -f /volumes/ssh_keys/ssh_host_ecdsa_key ]; then
	echo "The ssh_host_ecdsa_key does not exist and should be created. Consider setting SFTP_CONTAINER_KEYS=CREATE. This is an unrecoverable error."
	exit 2
fi

if [ ! -f /volumes/ssh_keys/ssh_host_ed25519_key ]; then
	echo "The ssh_host_ed25519_key does not exist and should be created. Consider setting SFTP_CONTAINER_KEYS=CREATE. This is an unrecoverable error."
	exit 2
fi

if [ ! -f /volumes/user/authorized_keys ]; then
	echo "The authorized_keys file does not exist in /volumes/user so no users will be able to connect. This is an unrecoverable error."
	exit 3
fi

if [ ! -s /volumes/user/authorized_keys ]; then
	echo "The authorized_keys file in the /volumes/user volume has no keys so no users will be able to connect. This is an unrecoverable error."
	exit 3
fi

# DATA_OWNER=$(ls -l /volumes | grep 'data$' | awk '{print $3}')
# if [[ ! "$DATA_OWNER" == "root" && ! "$DATA_OWNER" == "0" ]]; then
# 	echo "The /volumes/data volume must be owned by root. Sorry about that. This is an unrecoverable error."
# 	exit 4
# fi

if [ -z "$SFTP_CONTAINER_USER" ]; then
	echo "You must specify a SFTP_CONTAINER_USER environment variable"
	exit 1
fi

if [ -z "$SFTP_CONTAINER_GROUP" ]; then
	echo "You must specify a SFTP_CONTAINER_GROUP environment variable"
	exit 1
fi

GROUP_ID=$(getent group "$SFTP_CONTAINER_GROUP" | grep -Po '([0-9]+?):$' | sed 's/://g' 2> /dev/null)
GROUP_EXISTS=$?

if [ $GROUP_EXISTS == 0 ]; then 
	if [ -n "$SFTP_CONTAINER_GROUP_ID" ]; then
		if [ $GROUP_ID != $SFTP_CONTAINER_GROUP_ID ]; then
			echo "Existing group ID $GROUP_ID does not match specified group ID $SFTP_CONTAINER_GROUP_ID for group $SFTP_CONTAINER_GROUP"
			echo "This is an unrecoverable error"
			exit 1
		fi
	fi
else
	EXISTING_GROUP_FOR_ID=$(getent group $SFTP_CONTAINER_GROUP_ID | grep -Po '^.+?:' | sed 's/://' 2> /dev/null)
	if [ -n "$EXISTING_GROUP_FOR_ID" ]; then
		echo "Group with ID $SFTP_CONTAINER_GROUP_ID already exists as $EXISTING_GROUP_FOR_ID"
		echo "This is an unrecoverable error"
		exit 1
	fi

	groupadd -g $SFTP_CONTAINER_GROUP_ID $SFTP_CONTAINER_GROUP
fi

USER_ID=$(id -u $SFTP_CONTAINER_USER 2> /dev/null)
USER_EXISTS=$?

if [ $USER_EXISTS == 0 ]; then 
	if [ -n "$SFTP_CONTAINER_USER_ID" ]; then
		if [ $USER_ID != $SFTP_CONTAINER_USER_ID ]; then
			echo "Existing user ID $USER_ID does not match specified user ID $SFTP_CONTAINER_USER_ID for user $SFTP_CONTAINER_USER"
			echo "This is an unrecoverable error"
			exit 1
		fi
	fi
else
	EXISTING_USER_FOR_ID=$(id -un "$SFTP_CONTAINER_USER_ID" 2> /dev/null)
	if [ -n "$EXISTING_USER_FOR_ID" ]; then
		echo "User with ID $SFTP_CONTAINER_USER_ID already exists as $EXISTING_USER_FOR_ID"
		echo "This is an unrecoverable error"
		exit 1
	fi

	#use / as the home directory because SFTP will chroot this user to /
	#See http://www.debian-administration.org/article/590/OpenSSH_SFTP_chroot_with_ChrootDirectory
	useradd -s /usr/sbin/nologin -d / -g $SFTP_CONTAINER_GROUP -N -u $SFTP_CONTAINER_USER_ID $SFTP_CONTAINER_USER
fi

#Fixup permissions on authorized_key file
mkdir -p /ssh
cp /volumes/user/authorized_keys /ssh/authorized_keys

chown $SFTP_CONTAINER_USER:$SFTP_CONTAINER_GROUP /ssh
chown $SFTP_CONTAINER_USER:$SFTP_CONTAINER_GROUP /ssh/authorized_keys
chmod 700 /ssh
chmod 600 /ssh/authorized_keys

#Create the PrivSep emptry dir
mkdir /var/run/sshd
chmod 0755 /var/run/sshd

# Update config
update_ssh_config "SFTP_USER_UMASK" "0"

if [ "$SFTP_CONTAINER_DEBUG" == "DEBUG" ]; then
	/usr/sbin/sshd -d
else
	/usr/sbin/sshd -D
fi