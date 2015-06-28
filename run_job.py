#!/usr/bin/env python

import sys
import time
import hapy
import requests
import re
requests.packages.urllib3.disable_warnings()

def cmp(s1, s2):
  return re.search(s2, s1, re.IGNORECASE)

def get_state(h, job_name, verbose=False):
  if verbose:
    print 'getting job state for job %s' % job_name,
  info = h.get_job_info(job_name)
  job_state = info['job']['statusDescription']
  if verbose:
    print '=> %s' % job_state
  return job_state

def is_job_in_state(h, job_name, state):
  current_state = get_job_state(h, job_name)
  return cmp(current_state, state)

def wait_for_state(h, job_name, state, verbose=False):
  if verbose:
    print 'waiting for', state
  info = h.get_job_info(job_name)
  while not cmp(info['job']['statusDescription'], state):
    time.sleep(1)
    info = h.get_job_info(job_name)

def wait_for_available_action(h, job_name, action, verbose=False):
  if verbose:
    print 'waiting for', action
  info = h.get_job_info(job_name)
  while action not in info['job']['availableActions']['value']:
    time.sleep(1)
    info = h.get_job_info(job_name)

# main

try:
    name = sys.argv[1]
except IndexError:
    print "Usage: run_job.py job-name"
    sys.exit(1)

try:
    h = hapy.Hapy('https://localhost:8443', username='admin', password='password')
    state = get_state(h, name)
    if not(cmp(state, "aborted") or cmp(state, "finished")):
      print "job is currently in state %s" % state
      if cmp(state, "running"):
        print "job is running, stopping it"
        h.terminate_job(name)
        wait_for_state(h, name, "aborted")

    # job should be finished by now
    print "tearing down job"
    h.teardown_job(name)
    wait_for_state(h, name, "unbuilt")

    # now build it
    h.build_job(name)
    wait_for_state(h, name, "ready")
    
    # now start it
    h.launch_job(name)
    wait_for_state(h, name, "paused")
    
    # now run it
    h.unpause_job(name)
    wait_for_state(h, name, "running")

except hapy.HapyException as he:
    print 'something went wrong:', he.message