#!/usr/bin/env python

import sys
import time
import hapy
import requests
import re
requests.packages.urllib3.disable_warnings()

def get_job_state(h, job_name, verbose=False):
    if verbose:
        print 'getting job state for job %s' % job_name,
    info = h.get_job_info(job_name)
    job_state = info['job']['statusDescription']
    if verbose:
        print '=> %s' % job_state
    return job_state

def is_job_in_state(h, job_name, state):
    current_state = get_job_state(h, job_name)
    return re.search(state, current_state, re.IGNORECASE)

def wait_for(h, job_name, func_name):
    print 'waiting for', func_name
    info = h.get_job_info(job_name)
    while func_name not in info['job']['availableActions']['value']:
        time.sleep(1)
        info = h.get_job_info(job_name)

def cmp(s1, s2):
    return re.search(s2, s1, re.IGNORECASE)

try:
    name = sys.argv[1]
except IndexError:
    print "Usage: get_job_state.py job-name"
    sys.exit(1)

try:
    h = hapy.Hapy('https://localhost:8443', username='admin', password='password')
    state = get_job_state(h, name)
    print state
    if cmp(state, "aborted") or cmp(state, "finished"):
      print "job is aborted or finished"
    elif cmp(state, "running"):
      print "job is running"
    elif cmp(state, "unbuilt"):
      print "job is unbuilt"
    elif cmp(state, "ready"):
      print "job is ready"
    elif cmp(state, "preparing"):
      print "job is preparing"
    elif cmp(state, "paused"):
      print "job is paused"
    elif cmp(state, "stopping"):
      print "job is stopping"
    else:
      print "beats me!"
except hapy.HapyException as he:
    print 'something went wrong:', he.message
