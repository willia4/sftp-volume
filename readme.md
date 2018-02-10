# SFTP Volume Container

This image allows you to create a container that exposes a single volume (from another container or a host directory) over SFTP. 

The image supports a single SFTP user authenticated via any number of private keys (the main pitfall of this approach is that there is no way to tie an action to a specific person or computer when multiple people or computers are authenticated via their own private keys; this approach works well when only a single person or computer is expected to access this share).


##Configuration
### Server Keys
Expose a volume at `/volumes/ssh_keys` which contains the following files: 

* `/volumes/ssh_keys/ssh_host_rsa_key`
* `/volumes/ssh_keys/ssh_host_dsa_key`
* `/volumes/ssh_keys/ssh_host_ecdsa_key`
* `/volumes/ssh_keys/ssh_host_ed25519_key`

If you do not expose this volume, you ***must*** set SFTP_CONTAINER_KEYS='CREATE' (see below).

#### Automatically Create Keys
To have the container automaticall create its keys, set the environment variable SFTP_CONTAINER_KEYS='CREATE'.

***WARNING: If you expose a volume with keys and set this variable, your keys will be overwritten!***

Using this option repeatedly will confuse SFTP clients when they see new host keys each time they connect; however, it can be a good way to create initial keys.

#### Manually Create Keys
In your key directory on the host, run the following commands: 

	cd /my/key/directory

    ssh-keygen -f ./ssh_host_rsa_key -N '' -t rsa -b 4096; \
    ssh-keygen -f ./ssh_host_dsa_key -N '' -t dsa; \
    ssh-keygen -f ./ssh_host_ecdsa_key -N '' -t ecdsa -b 521; \
    ssh-keygen -f ./ssh_host_ed25519_key -N '' -t ed25519; 

### User ID
This image supports a single user authenticated by one or more private keys. Specify the username for this user via the SFTP_CONTAINER_USER environment variable. Specify the group name for this user via the SFTP_CONTAINER_GROUP environment variable. 

This user and group will be created if they do not exist in the container (the container has stock ubuntu users already). Pass in a user and group ID to control which IDs they should be created with as SFTP_CONTAINER_USER_ID and SFTP_CONTAINER_GROUP_ID. 

To manage permissions, the user and user id as well as the group and group id should map to the the same values on the system or container hosting the volumes.

### User Keys
Expose a volume at `/volumes/user/` which contains an `authorized_keys` file (so `/volumes/user/authorized_keys`). 

This file should mimic a standard ~/.ssh/authorized_key file and list the public keys that should be allowed access. 

### Data
Any directories that should be available for SFTP should be expose as volumes of a subdirectory under /volumes/sftp_root. 
For example, to share the directory "www", add it as a volume named "/volumes/sftp_root/www". 

The permissions for these directories will transfer, so they should be readable and writable by SFTP_CONTAINER_USER or SFTP_CONTAINER_GROUP.
Unfortunately, this mechanism works extremely poorly (or, not at all) with docker-machine or boot2docker and host-mounted volumes. When using these tools, data-only containers should be considered. 

### Permissions
You can set the umask for the sftp user via the SFTP_USER_UMASK environment variable. Set this environment variable to the decimal representation of the desired octal bitmask (for example, if desired umask is octal 011, set SFTP_USER_UMASK to decimal 73). By default, the umask will be 0.

### Debug
To see debug output directly from the SSH daemon, set the SFTP_CONTAINER_DEBUG environment variable to "DEBUG". Note that this puts the SSH daemon in a debug mode which is not suitable for production use. 

## Example
In this example, the host is serving static files from /www via nginx. The files are owned by www-data. To make these files accessible over SFTP, the following steps could be taken. 

Create a directory to hold the host keys for the SFTP server and create the keys:

    mkdir /sftp_keys
    ssh-keygen -f /sftp_keys/ssh_host_rsa_key -N '' -t rsa -b 4096
    ssh-keygen -f /sftp_keys/ssh_host_dsa_key -N '' -t dsa
    ssh-keygen -f /sftp_keys/ssh_host_ecdsa_key -N '' -t ecdsa -b 521
    ssh-keygen -f /sftp_keys/ssh_host_ed25519_key -N '' -t ed25519

Create the authorized_keys file for your user(s) who should have SFTP access:

   mkdir /sftp_user
   cp $AUTHORIZED_KEYS /sftp_user/

Get the user ID and group ID of the www-data users and group: 

	id www-data
	    uid=33(www-data) gid=33(www-data) groups=33(www-data)

Ensure the permissions are correct on the host system:

    chown www-data:www-data /www


Run the container; pick an SFTP port to represent this directory and map it to port 22:

    docker run -d \
    -e SFTP_CONTAINER_USER="www-data" \
    -e SFTP_CONTAINER_USER_ID="33" \
    -e SFTP_CONTAINER_GROUP="www-data" \
    -e SFTP_CONTAINER_GROUP_ID="33" \
    -v "/sftp_keys:/volumes/ssh_keys" \
    -v "/www:/volumes/sftp_root/www" \
    -v "/sftp_user:/volumes/user" \
    -p 4577:22 willia4/sftp_volume

From a client, connect an SFTP client to port 4577 using the appropriate private key.     