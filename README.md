# Web Archiving Appliance Proof-of-Concept

## What is this?

This is a proof-of-concept of a Web Archiving appliance. It will archive
(crawl) sites of your choosing, and will allow you to browse them "wayback
machine" style. It uses Heritrix for the crawling/archiving and openwayback
for the browsing.

## How do I use this?

This is packaged in the form of a ready-to-run [Vagrant](https://www.vagrantup.com) instance.
Simply install Vagrant, and type `vagrant up` while in this directory.

## Heritrix documentation notes

The main Heritrix documentation can be found
[here](https://webarchive.jira.com/wiki/display/Heritrix/Heritrix+3.0+and+3.1+User+Guide).

Pages of particular note:
* [Guide to using the Web UI](https://webarchive.jira.com/wiki/display/Heritrix/Web-based+User+Interface)
* [Running your first crawl job](https://webarchive.jira.com/wiki/display/Heritrix/A+Quick+Guide+to+Running+Your+First+Crawl+Job)

Notes/errata:
* configuration file needs to be edited for each job
  located in `/opt/heritrix-3.2.0/jobs/JOBNAME/crawler-beans.cxml`.
  At the very least you must:
  * set a valid URL (http or https) `metadata.operatorContactUrl`. This is sent as part of the `User-Agent` string and should contain information on your organization, the idea being that it is a place for the webmaster of the site you're crawling to contact in case something is wrong, etc.
  * add some URLs to crawl in the `props` array under `longerOverrides`
* the config file is NOT editable via the web UI (as the documentation implies),
  you must `ssh` in and edit it using a text editor (`vim`, `nano`, etc.)
