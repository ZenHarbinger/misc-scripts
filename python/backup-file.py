#!/usr/bin/env python
# tar and gpg encrypt a file or directory and copy it locally
# the local destination could be a remote share or rsync'd location
# e.g.
# ./backup-file.py --recipient 01234556 --data somefile --backup /backup/location --backupname backupfile --verbose on

import argparse
import sys
import os
import time

# define our arguments
parser=argparse.ArgumentParser()
parser.add_argument('--recipient',help="GPG recipient")
parser.add_argument('--data',help="data to backup")
parser.add_argument('--backup',help="backup destination")
parser.add_argument('--backupname',help="backup file name")
parser.add_argument("--verbose", help="increase verbosity output")

# print help if no arguments are provided
if len(sys.argv)==1:
    parser.print_help()
    sys.exit(1)
args=parser.parse_args()

# make a variable for timestamp, e.g. 2015471826
timestamp = str(time.localtime().tm_year) + str(time.localtime().tm_mon) + str(time.localtime().tm_mday) + str(time.localtime().tm_hour) + str(time.localtime().tm_min)

# print options if verbose is turned on
if args.verbose:
    print "verbosity turned on"
    if args.recipient:
        print "Recipient: " + args.recipient
    if args.data:
        print "Data: " + args.data 
    if args.backup:
        print "Backup To: " + args.backup
    if args.backupname:
        print "Backup Name: " + args.backupname + timestamp

# check if backup file exists
if os.path.exists(args.backup + '/' + args.backupname + timestamp + '.tar.gz.gpg'):
    print "ERROR, Backup Name: -> " + args.backupname + timestamp + " Exists!"
    sys.exit(1)

# check if file open would succeed and you are using a sane location
try:
       open(args.backup + '/' + args.backupname + timestamp + '.tar.gz.gpg', 'w')
except IOError:
       print "Unable to open the backup destination."

# define our tar and encrypt commands
from subprocess import Popen, PIPE
gpg_output = open(args.backup + '/' + args.backupname + timestamp + '.tar.gz.gpg', 'w')
tar_command = Popen(['tar', '-cvz', args.data], stdout=PIPE)
gpg_command = Popen(['gpg', '-e', '-r', args.recipient], stdin=tar_command.stdout, stdout=gpg_output)
out, err = gpg_command.communicate()
