#!/usr/bin/env python
# Filename:                nova_mem_cpu_calc.py
# Supported Langauge(s):   Python 2.7.x
# Time-stamp:              <2016-06-15 09:20:29 jfulton> 
# -------------------------------------------------------
# This program was originally written by Ben England
# -------------------------------------------------------
# Calculates cpu_allocation_ratio and reserved_host_memory
# for nova.conf based on on the following inputs: 
#
# input command line parameters:
# 1 - total host RAM in GB
# 2 - total host cores 
# 3 - average guest size in GB
# 4 - Ceph OSDs per server
#
# It assumes that we want to allow 3 GB per OSD 
# (based on prior Ceph Hammer testing)
# and that we want to allow an extra 1/2 GB per Nova (KVM guest)
# based on test observations that KVM guests' virtual memory footprint
# was actually significantly bigger than the declared guest memory size
# This is more of a factor for small guests than for large guests.
# -------------------------------------------------------
import sys
from sys import argv

NOTOK = 1  # process exit status signifying failure
MB_per_GB = 1000

GB_per_OSD = 3
GB_overhead_per_guest = 0.5  # based on measurement in test environment

def usage(msg):
  print msg
  print "Usage: %s Total-host-RAM-GB Total-host-cores Avg-guest-size-GB OSDs-per-server" % sys.argv[0]
  sys.exit(NOTOK)

if len(argv) < 5: usage("Too few command line params")
try:
  mem = int(argv[1])
  cores = int(argv[2])
  average_guest_size = int(argv[3])
  osds = int(argv[4])
except ValueError:
  usage("Non-integer input parameter")

# print inputs
print "Inputs:"
print "- Total host RAM in GB: %d" % mem
print "- Total host cores: %d" % cores
print "- Average guest size in GB: %d" % average_guest_size
print "- Ceph OSDs per host: %d" % osds

# calculate operating parameters based on memory constraints only
left_over_mem = mem - (GB_per_OSD * osds)
number_of_guests = int(left_over_mem / 
                       (average_guest_size + GB_overhead_per_guest))
nova_reserved_mem_MB = MB_per_GB * int(left_over_mem - 
                       (number_of_guests * GB_overhead_per_guest))
cpu_allocation_ratio = float((cores - osds)) / float(cores)

# display outputs including how to tune Nova reserved mem

print "\nResults:"
print "- number of guests allowed = %d" % number_of_guests
print "- nova.conf reserved_host_memory = %d MB" % nova_reserved_mem_MB
print "- nova.conf cpu_allocation_ratio = %f" % cpu_allocation_ratio

if nova_reserved_mem_MB < 0:
    print "ERROR: you do not have enough memory to run hyperconverged!"
    sys.exit(NOTOK)
