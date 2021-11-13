#!/bin/sh

set -e

#############################################################################
# please modify to use your own file
#############################################################################
uri="https://raw.githubusercontent.com/centminmod/centminmod-sshremotekeys/master/userkeys.sh"

check_uri=$(curl -4ILs --connect-timeout 30 --max-time 30 "$uri" | grep 'HTTP\/' | grep -o '200' >/dev/null 2>&1; echo $?)

# only run if valid userkeys.sh download location exists
if [[ "$check_uri" -eq '0' ]]; then
  # download to the host your custom userkeys.sh
  curl -4 $uri --create-dirs -o /usr/local/bin/userkeys.sh
  
  # set file permissions
  if [ -f /usr/local/bin/userkeys.sh ]; then
    chmod 555 /usr/local/bin/userkeys.sh
  fi
  
  
  #############################################################################
  # modifies sshd_config with the following settings:
  #############################################################################
  
  # enables publickey login
  sed -i 's/PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
  sed -i 's/PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
  
  # configures AuthorizedKeysCommand to execute userkeys.sh on each login
  if [ ! "$(grep 'AuthorizedKeysCommand /usr/local/bin/userkeys.sh' /etc/ssh/sshd_config)" ]; then
    echo "AuthorizedKeysCommand /usr/local/bin/userkeys.sh" >> /etc/ssh/sshd_config
  fi
  
  # sets the user to root in order to save the cache key files in users home
  if [ ! "$(grep 'AuthorizedKeysCommandUser root' /etc/ssh/sshd_config)" ]; then
    echo "AuthorizedKeysCommandUser root" >> /etc/ssh/sshd_config
  fi
  
  # sets the cache key file name
  if [ ! "$(grep authorized_keys_cache /etc/ssh/sshd_config)" ]; then
    sed -i 's/AuthorizedKeysFile.*/AuthorizedKeysFile .ssh\/authorized_keys .ssh\/authorized_keys_cache/' /etc/ssh/sshd_config
  fi
  
  # make sure all host keys exist
  ssh-keygen -A
  
  # make sure ~/.ssh exists
  mkdir -p /root/.ssh
  
  # make sure sshd_config is valid
  sshd -t
  
  # restart ssh or sshd depending of the distro
  service ssh restart ; service sshd restart
else
  echo "error: check uri variable"
  echo "$uri isn't valid"
fi
