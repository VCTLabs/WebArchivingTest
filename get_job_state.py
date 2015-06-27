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
    print state
except hapy.HapyException as he:
    print 'something went wrong:', he.message
