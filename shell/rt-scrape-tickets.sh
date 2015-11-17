#!/bin/sh
# Tool to query and scrape RT status for use with
# announcing new, unowned tickets in an IRC channel
# we use this with the supybot-notify plugin

TMPHTML=$(mktemp /tmp/ticketsXXXXXXXX.html)
TMPFILE=$(mktemp /tmp/ticketsXXXXXXXX)
TMPFILE2=$(mktemp /tmp/ticketsXXXXXXXX)

function report {
 echo \#example-channel "$1" | nc -w 5 127.0.0.1 5050
}

debug=false
tdir=/root/oslab-tickets

if [ "$1" = "debug" ]; then
  debug=true
fi

keytab=/root/example-host01.keytab
princ=myuser/host01.example.com@EXAMPLE.COM

# first get the krb ticket
kinit -f -k -t myuser.keytab myuser/host01.example.com/@EXAMPLE.COM

# now curl and scrape the tickets page
# your-queue should be your queue
curl --insecure -s --negotiate -u :  -o -
'https://engineering.example.com/rt/Search/Results.html?Query=Queue%20%3D%20%27your-queue%27%20AND%20%28Status%20%3D%20%27new%27%20OR%20Status%20%3D%20%27open%27%20OR%20Status%20%3D%20%27stalled%27%20OR%20Status%20%3D%20%27needinfo%27%29' > $TMPHTML
elinks -dump-width 1000 -dump 1 $TMPHTML | sed '1,/Gantt Chart/d' | sed '/Time to display:/,$d' > $TMPFILE

# links to the tickets will look like this:
#   https://engineering.example.com/rt/Ticket/Display.html?id=<ticket #>
cat $TMPFILE | sed '1,/^$/d' | sed '/^$/,$d' | sed '1,2d' > $TMPFILE2

############
# example of the above in $TMPFILE2.  Note that the dump-width is intentionally set high to ensure $subject stays on one line.
# and the lines should always be two per ticket.
#
# <--snip-->
#    [94]278371 [95]Integrate rsyslog's into scalelab logstash instance                                      stalled     openstack-scalelab Nobody                         0
#               wfoster@example.com                                                                          2 years ago                    6 weeks ago
#    [98]375788 [99]IP address space for OpenStack Deployment                                                stalled     openstack-scalelab Nobody                         0
#               user@example.com                                                                             4 weeks ago 5 days ago         5 days ago
# <--snip-->
############

cat $TMPFILE2 | while read line1 ; do
read line2
words=$(echo $line1 | wc -w)
spot=$(expr $words - 3)
front=$(echo $line1 | cut -d" " -f 1-$(expr $spot - 1))
back=$(echo $line1 | cut -d" " -f $spot-)
status=$(echo $back | awk '{ print $1 }')
owner=$(echo $back | awk '{ print $3 }')
number=$(echo $front | cut -d" " -f 1-1 | sed 's/\[[0-9]*\]//g')
subject=$(echo $front | cut -d" " -f 2- | sed 's/\[[0-9]*\]//g')
reporter=$(echo $line2 | awk '{ print $1 }')

if $debug ; then
  echo Ticket '#' $number, Subject = $subject, Status = $status, Owner = $owner, Reported by = $reporter, URL = 'https://engineering.example.com/rt/Ticket/Display.html?id='$number
fi

if [ ! -d $tdir ]; then
  mkdir -p $tdir
fi

if [ ! -d $tdir/$number ]; then
  mkdir -p $tdir/$number
fi

if [ -f $tdir/$number/owner ]; then
  curowner=$(cat $tdir/$number/owner)
  if [ "$owner" != "$curowner" ]; then
    report "Ticket # $number, owner changed from $curowner to $owner. URL = https://engineering.example.com/rt/Ticket/Display.html?id=$number"
    echo $owner > $tdir/$number/owner
  fi
else
  echo $owner > $tdir/$number/owner
fi

if [ -f $tdir/$number/status ]; then
  curstatus=$(cat $tdir/$number/status)
  if [ "$status" != "$curstatus" ]; then
    report "Ticket # $number, status changed from $curstatus to $status. URL = https://engineering.example.com/rt/Ticket/Display.html?id=$number"
    echo $status > $tdir/$number/status
  fi
else
  echo $status > $tdir/$number/status
fi

if [ -f $tdir/$number/subject ]; then
  cursubject=$(cat $tdir/$number/subject)
  if [ "$subject" != "$cursubject" ]; then
    report "Ticket # $number, subject changed from $cursubject to $subject. URL = https://engineering.example.com/rt/Ticket/Display.html?id=$number"
    echo $subject > $tdir/$number/subject
  fi
else
  echo $subject > $tdir/$number/subject
fi

if [ -f $tdir/$number/reporter ]; then
  curreporter=$(cat $tdir/$number/reporter)
  if [ "$reporter" != "$curreporter" ]; then
    report "Ticket # $number, reporter changed from $curreporter to $reporter. URL = https://engineering.example.com/rt/Ticket/Display.html?id=$number"
    echo $reporter > $tdir/$number/reporter
  fi
else
  echo $reporter > $tdir/$number/reporter
fi

curtime=$(date +%s)

if [ "$owner" = "Nobody" ]; then
  if [ -f $tdir/$number/nagtime ]; then
    if [ $(expr $curtime - $(cat $tdir/$number/nagtime)) -gt 21600 ]; then
      report "Ticket # $number, owner = Nobody. URL = https://engineering.example.com/rt/Ticket/Display.html?id=$number"
    fi
  else
    report "(RT-oslab) $subject,  # $number, owner = Nobody. URL = https://engineering.example.com/rt/Ticket/Display.html?id=$number"
    echo $curtime > $tdir/$number/nagtime
  fi
fi

done

rm -f $TMPFILE $TMPFILE2 $TMPHTML
