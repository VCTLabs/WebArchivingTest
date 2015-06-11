#!/usr/bin/env bash

sha1verify() {
  FILE="$1"
  HASH="$2"
  FILEHASH=$(openssl sha1 $FILE)
  if [ "SHA1(${FILE})= $2" = "${FILEHASH}" ]; then  return 0; else return 1; fi
}

apt-get update
apt-get install -y build-essential w3m elinks screen default-jdk
cd /tmp
wget --no-verbose http://builds.archive.org/maven2/org/archive/heritrix/heritrix/3.2.0/heritrix-3.2.0-dist.tar.gz
wget --no-verbose http://builds.archive.org/maven2/org/archive/heritrix/heritrix/3.2.0/heritrix-3.2.0-dist.tar.gz.sha1
#http://builds.archive.org/maven2/org/archive/heritrix/heritrix/3.2.0/heritrix-3.2.0-src.tar.gz
#http://builds.archive.org/maven2/org/archive/heritrix/heritrix/3.2.0/heritrix-3.2.0-src.tar.gz.sha1
if ! sha1verify "heritrix-3.2.0-dist.tar.gz" "`cat heritrix-3.2.0-dist.tar.gz.sha1`"; then
  echo "ERROR: download failed! (checksum mismatch)"
  exit 1
fi

mkdir -p /opt
tar -C /opt -xvzf /tmp/heritrix-3.2.0-dist.tar.gz
chmod 755 /opt/heritrix-3.2.0/bin/heritrix
cat << _EOF_PROFILE_SH_ > /etc/profile.d/heritrix.sh
export PATH=$PATH:/opt/heritrix-3.2.0/bin
export JAVA_HOME=/usr/lib/jvm/default-java
export HERITRIX_HOME=/opt/heritrix-3.2.0
export JAVA_OPTS=-Xmx1024M
_EOF_PROFILE_SH_
chmod 644 /etc/profile.d/heritrix.sh
chown -R vagrant:vagrant /opt/heritrix-3.2.0

cat << _EOF_START_SH_ > /home/vagrant/start_heritrix.sh
#!/bin/sh
exec heritrix -a demo:demo -b /
_EOF_START_SH_

cp /vagrant/README.md /home/vagrant
chown vagrant:vagrant /home/vagrant/README.md /home/vagrant/start_heritrix.sh
chmod 644 /home/vagrant/README.md
chmod 755 /home/vagrant/start_heritrix.sh

IPADDR=`ifconfig eth1 | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p'`
echo ""
echo "Run Heritrix using the \`start_heritrix.sh' script."
echo "It can be accessed via the web (https, self-signed cert) at:"
echo "     https://$IPADDR:8443/"
echo ""
echo "The default username/password is \`demo:demo'."
echo "They can be changed in the \`start_heritrix.sh' script."
echo ""
echo "Share And Enjoy!"
