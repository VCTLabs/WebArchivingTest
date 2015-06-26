#!/usr/bin/env python

import hapy
import requests
requests.packages.urllib3.disable_warnings()

try:
    h = hapy.Hapy('https://localhost:8443', username='admin', password='password')
    info = h.get_job_info('crawler')
    launch_count = int(info['job']['launchCount'])
    print 'crawler has been launched %d time(s)' % launch_count
except hapy.HapyException as he:
    print 'something went wrong:', he.message
