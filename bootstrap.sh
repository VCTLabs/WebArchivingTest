#!/usr/bin/env bash

# handy dandy routine to verify SHA1 sums
# usage: sha1verify <filename> <sha1>
# exit 0 = success, 1 = fail
sha1verify() {
  FILE="$1"
  HASH="$2"
  FILEHASH=$(openssl sha1 $FILE)
  if [ "SHA1(${FILE})= $2" = "${FILEHASH}" ]; then  return 0; else return 1; fi
}

# set hostname
hostname wayback
IPADDR=`ifconfig eth1 | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p'`
echo "$IPADDR wayback" >> /etc/hosts

# install packages and stuff
echo "Updating/installing packages..."
apt-get -q=2 update
apt-get -q=2 install -y build-essential git libdb-dev maven2 mosh openjdk-7-jdk tomcat7 tomcat7-docs tomcat7-admin tomcat7-examples vim w3m elinks screen # default-jdk

# download heritrix
echo "Downloading Heritrix..."
cd /tmp
wget --no-verbose http://builds.archive.org/maven2/org/archive/heritrix/heritrix/3.2.0/heritrix-3.2.0-dist.tar.gz
wget --no-verbose http://builds.archive.org/maven2/org/archive/heritrix/heritrix/3.2.0/heritrix-3.2.0-dist.tar.gz.sha1
#http://builds.archive.org/maven2/org/archive/heritrix/heritrix/3.2.0/heritrix-3.2.0-src.tar.gz
#http://builds.archive.org/maven2/org/archive/heritrix/heritrix/3.2.0/heritrix-3.2.0-src.tar.gz.sha1
if ! sha1verify "heritrix-3.2.0-dist.tar.gz" "`cat heritrix-3.2.0-dist.tar.gz.sha1`"; then
  echo "ERROR: download failed! (checksum mismatch)"
  exit 1
fi

# install heritrix
echo "Installing Heritrix..."
mkdir -p /opt
tar -C /opt -xzf /tmp/heritrix-3.2.0-dist.tar.gz
chmod 755 /opt/heritrix-3.2.0/bin/heritrix
cat << _EOF_PROFILE_SH_ > /etc/profile.d/heritrix.sh
export PATH=$PATH:/opt/heritrix-3.2.0/bin
export JAVA_HOME=/usr/lib/jvm/default-java
export HERITRIX_HOME=/opt/heritrix-3.2.0
export JAVA_OPTS=-Xmx1024M
_EOF_PROFILE_SH_
chmod 644 /etc/profile.d/heritrix.sh
chown -R vagrant:vagrant /opt/heritrix-3.2.0

# make handy startup script
cat << _EOF_START_SH_ > /home/vagrant/start_heritrix.sh
#!/bin/sh
exec heritrix -a admin:password -b /
_EOF_START_SH_

# set up tomcat
echo "Setting up Tomcat..."
service tomcat7 stop
# openwayback needs Java 7
echo JAVA_HOME=/usr/lib/jvm/java-1.7.0-openjdk-i386 >> /etc/default/tomcat7
# set hostname
sed -i.bak -e '/Host name=/{N;N;s/$/\n\<Alias\>wayback\<\/Alias\>/}' /etc/tomcat7/server.xml
# add admin user
sed -i.bak -e '/<tomcat-users>/a<user username="admin" password="password" roles="manager-gui,admin-gui"/>' /etc/tomcat7/tomcat-users.xml

# install openwayback
# using maven overlay
#cd /tmp && git clone https://github.com/VCTLabs/openwayback-sample-overlay.git
#cd openwayback-sample-overlay && mvn install
# using tar file
echo "Downloading OpenWayback..."
cd /tmp
wget --no-verbose -O openwayback-dist-2.2.0.tar.gz http://search.maven.org/remotecontent?filepath=org/netpreserve/openwayback/openwayback-dist/2.2.0/openwayback-dist-2.2.0.tar.gz
echo "Installing OpenWayback..."
tar xzf openwayback-dist-2.2.0.tar.gz
rm -rf /var/lib/tomcat7/webapps/ROOT
#cp target/openwayback-sample-overlay-2.0.0.BETA.1.war /var/lib/tomcat7/webapps/ROOT.war
cp openwayback/openwayback-2.2.0.war /var/lib/tomcat7/webapps/ROOT.war
cd / && rm -rf /tmp/openwayback
echo "Restarting Tomcat..."
service tomcat7 start

# wait for tomcat to unpack
echo "Waiting for Tomcat to unpack WAR..."
while [ ! -f /var/lib/tomcat7/webapps/ROOT/WEB-INF/wayback.xml ]; do
  sleep 1
done
# set up openwayback
echo "Configuring OpenWayback..."
sed -i.bak -e 's/\(wayback.url.host.default=\).*/\1wayback/' -e 's/\(wayback.archivedir.1=\).*/\1\/opt\/heritrix-3.2.0\/jobs\/job1/' -e 's/\(wayback.archivedir.2=\).*/\1\/opt\/heritrix-3.2.0\/jobs\/job2/' /var/lib/tomcat7/webapps/ROOT/WEB-INF/wayback.xml
echo "Restarting Tomcat..."
service tomcat7 restart

# copy in handy stuffs
cp /vagrant/README.md /home/vagrant
chown vagrant:vagrant /home/vagrant/README.md /home/vagrant/start_heritrix.sh
chmod 644 /home/vagrant/README.md
chmod 755 /home/vagrant/start_heritrix.sh

# all done
echo " "
echo "Run Heritrix using the \`start_heritrix.sh' script."
echo "It can be accessed via the web (https, self-signed cert) at:"
echo "     https://$IPADDR:8443/"
echo " "
echo "The default username/password is \`admin:password'."
echo "They can be changed in the \`start_heritrix.sh' script."
echo " "
echo "To access openwayback, browse to: (note: http, NOT https as above)"
echo "     http://$IPADDR:8080/wayback/"
echo " "
echo "To manage tomcat, browse to"
echo "      http://$IPADDR:8080/manager/html"
echo "The default username/password is \`admin:password'."
echo " "
echo "Share And Enjoy!"
