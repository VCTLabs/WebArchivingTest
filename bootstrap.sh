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
apt-get -q=2 update > /dev/null 2>&1
apt-get -q=2 install -y curl openjdk-7-jdk python-software-properties screen tomcat7 tomcat7-admin vim > /dev/null 2>&1

# install mosh
echo "Installing mosh..."
echo "" | add-apt-repository ppa:keithw/mosh
apt-get update > /dev/null 2>&1
apt-get install -y mosh > /dev/null 2>&1

# download heritrix
echo "Downloading Heritrix..."
mkdir -p /tmp/setup.$$
cd /tmp/setup.$$
wget --no-verbose -O /tmp/setup.$$/heritrix-3.2.0-dist.tar.gz http://builds.archive.org/maven2/org/archive/heritrix/heritrix/3.2.0/heritrix-3.2.0-dist.tar.gz
wget --no-verbose -O /tmp/setup.$$/SHA1SUM http://builds.archive.org/maven2/org/archive/heritrix/heritrix/3.2.0/heritrix-3.2.0-dist.tar.gz.sha1
#http://builds.archive.org/maven2/org/archive/heritrix/heritrix/3.2.0/heritrix-3.2.0-src.tar.gz
#http://builds.archive.org/maven2/org/archive/heritrix/heritrix/3.2.0/heritrix-3.2.0-src.tar.gz.sha1
if ! sha1verify "/tmp/setup.$$/heritrix-3.2.0-dist.tar.gz" "`cat /tmp/setup.$$/SHA1SUM`"; then
  echo "ERROR: download failed! (checksum mismatch)"
  exit 1
fi

# install heritrix
echo "Installing Heritrix..."
mkdir -p /opt
tar -C /opt -xzf /tmp/setup.$$/heritrix-3.2.0-dist.tar.gz
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

# start up heritrix
echo "Starting up heritrix..."
. /etc/profile.d/heritrix.sh
su - vagrant /home/vagrant/start_heritrix.sh
# give it some time to spin up
sleep 10

# set up heritrix job
echo "Setting up Heritrix job..."
curl -qso /dev/null -d "createpath=crawler&action=create" -k -u admin:password --anyauth --location https://localhost:8443/engine
echo "Configuring Heritrix job..."
sed -i.bak -e 's/\(metadata.operatorContactUrl=\).*/\1http:\/\/vctlabs.com\//' -e '/URLS HERE/a\
http://otakunopodcast.com\
http://donaldburr.com\
http://vctlabs.com' -e '/example.example\/example/d' -e '/WARCWriterProcessor/a\
\<property name=\"directory\" value=\"\/var\/spool\/heritrix\/\" \/\>' /opt/heritrix-3.2.0/jobs/crawler/crawler-beans.cxml
mkdir -p /var/spool/heritrix
chown vagrant:vagrant /var/spool/heritrix
chmod 755 /var/spool/heritrix
echo "Building job configuration..."
curl -qso /dev/null -d "action=build" -k -u admin:admin --anyauth --location https://localhost:8443/engine/job/crawler
echo "Launching job..."
curl -qso /dev/null -d "action=launch" -k -u admin:password --anyauth --location https://localhost:8443/engine/job/crawler
curl -qso /dev/null -d "action=unpause" -k -u admin:password --anyauth --location https://localhost:8443/engine/job/crawler

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
echo "Downloading OpenWayback..."
wget --no-verbose -O /tmp/setup.$$/openwayback-dist-2.2.0.tar.gz http://search.maven.org/remotecontent?filepath=org/netpreserve/openwayback/openwayback-dist/2.2.0/openwayback-dist-2.2.0.tar.gz
echo "Installing OpenWayback..."
tar xzf /tmp/setup.$$/openwayback-dist-2.2.0.tar.gz
rm -rf /var/lib/tomcat7/webapps/ROOT
#cp target/openwayback-sample-overlay-2.0.0.BETA.1.war /var/lib/tomcat7/webapps/ROOT.war
cp openwayback/openwayback-2.2.0.war /var/lib/tomcat7/webapps/ROOT.war
echo "Restarting Tomcat..."
service tomcat7 start

# wait for tomcat to unpack
echo "Waiting for Tomcat to unpack WAR..."
while [ ! -f /var/lib/tomcat7/webapps/ROOT/WEB-INF/wayback.xml ]; do
  sleep 1
done
# need to wait a bit more for it to finish
sleep 10

# set up openwayback
echo "Configuring OpenWayback..."
sed -i.bak -e 's/\(wayback.url.host.default=\).*/\1wayback/' -e 's/\(wayback.archivedir.1=\).*/\1\/var\/spool\/heritrix\/warcs\//' -e 's/\(wayback.archivedir.2=\).*/\1\/tmp\//' /var/lib/tomcat7/webapps/ROOT/WEB-INF/wayback.xml
echo "Restarting Tomcat..."
service tomcat7 restart

# copy in handy stuffs
cp /vagrant/README.md /home/vagrant
chown vagrant:vagrant /home/vagrant/README.md /home/vagrant/start_heritrix.sh
chmod 644 /home/vagrant/README.md
chmod 755 /home/vagrant/start_heritrix.sh

# copy in ssh key
if [ -f /vagrant/ssh_public_key ]; then
  echo "Copying in ssh key..."
  cat /vagrant/ssh_public_key >> /home/vagrant/.ssh/authorized_keys
fi

# all done
rm -rf /tmp/setup.$$
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
