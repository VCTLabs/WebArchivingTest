# Web Archiving Appliance Proof-of-Concept

## What is this?

This is a proof-of-concept of a Web Archiving appliance. It will archive
(crawl) sites of your choosing, and will allow you to browse them "wayback
machine" style. It uses [Heritrix](https://webarchive.jira.com/wiki/display/Heritrix/Heritrix) for the crawling/archiving and
[openwayback](https://github.com/iipc/openwayback) for the browsing.

## How do I use this?

This is packaged in the form of a ready-to-run [Vagrant](https://www.vagrantup.com) instance.

To get this going:
1. Install Vagrant.
2. Edit the `Vagrantfile` located here.
   * The one mandatory change is to set the `config.vm.network` line for the
   `public_network`. Currently this is set to bridge to a physical network
   interface, so that the VM can be accessed by a regular IP address on your
   network. If you want this behavior, you must set the network interface
   name (after the "`bridge =>`" statement.)
   For Macs, this should look like `en0: Ethernet` (yes, including the space) and for Linux boxen, this should be a more normal-looking network interface like `eth0` or `wlan0`.
   * The virtual interface's MAC address is `0A:B4:A0:A4:46:42`, so you may want to give it a static IP or something.

## Heritrix documentation notes

The main Heritrix documentation can be found
[here](https://webarchive.jira.com/wiki/display/Heritrix/Heritrix+3.0+and+3.1+User+Guide).

Pages of particular note:
* [Guide to using the Web UI](https://webarchive.jira.com/wiki/display/Heritrix/Web-based+User+Interface)
* [Running your first crawl job](https://webarchive.jira.com/wiki/display/Heritrix/A+Quick+Guide+to+Running+Your+First+Crawl+Job)
* [Heritrix API Guide](https://webarchive.jira.com/wiki/display/Heritrix/Heritrix+3.x+API+Guide#Heritrix3.xAPIGuide-BuildJobConfiguration) (you can control a running Heritrix with HTTP GET/POST requests. It even works with shell scripts with `curl`.)

Notes/errata on the Heritrix configuration:
* configuration file needs to be edited for each job
  located in `/opt/heritrix-3.2.0/jobs/JOBNAME/crawler-beans.cxml`.
  At the very least you must:
  * set a valid URL (http or https) `metadata.operatorContactUrl`. This is sent as part of the `User-Agent` string and should contain information on your organization, the idea being that it is a place for the webmaster of the site you're crawling to contact in case something is wrong, etc.
  * add some URLs to crawl in the `props` array under `longerOverrides`
* the config file is NOT editable via the web UI (as the documentation implies),
  you must `ssh` in and edit it using a text editor (`vim`, `nano`, etc.)

Notes/errata on the OpenWayback configuration:
* the provided OpenWayback config is set to look in the following two
  directories for warc-files. So use the job-names `job1` and `job2` when
  creating test jobs.
  * /opt/heritrix-3.2.0/jobs/job1
  * /opt/heritrix-3.2.0/jobs/job2
