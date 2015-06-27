#!/usr/bin/env python

import sys
import time
import hapy
import requests
requests.packages.urllib3.disable_warnings()

def get_job_state(h, job_name):
    print 'getting job state for job %s' % job_name,
    info = h.get_job_info(job_name)
    job_state = info['job']['availableActions']['value']
    print '=> %s' % job_state
    return job_state

def wait_for(h, job_name, func_name):
    print 'waiting for', func_name
    info = h.get_job_info(job_name)
    while func_name not in info['job']['availableActions']['value']:
        time.sleep(1)
        info = h.get_job_info(job_name)

name = sys.argv[1]
try:
    h = hapy.Hapy('https://localhost:8443', username='admin', password='password')
    state = get_job_state(h, name)
    if state == "teardown":
        print "job is ready to be re-run"
        h.teardown_job(name)
        print "waiting for build"
        wait_for(h, name, 'build')
        print "building job"
        h.build_job(name)
        print "waiting for launch"
        wait_for(h, name, 'launch')
        print "launching job"
        h.launch_job(name)
        print "waiting for pause"
        wait_for(h, name, 'unpause')
        print "unpausing job"
        h.unpause_job(name)        
    else:
        print "waiting for build"
        wait_for(h, name, 'build')
        print "building job"
        h.build_job(name)
        print "waiting for launch"
        wait_for(h, name, 'launch')
        print "launching job"
        h.launch_job(name)
        print "waiting for pause"
        wait_for(h, name, 'unpause')
        print "unpausing job"
        h.unpause_job(name)        
except hapy.HapyException as he:
    print 'something went wrong:', he.message
