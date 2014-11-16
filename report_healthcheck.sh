#!/bin/sh

##############################################################
# Copyright 2014 Daniel Grant
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
##############################################################

##############################################################
# report_health.sh
#
# Script that makes a number of calls to gather information
# about the servers health, and reports this information via
# email.
#
# Author:		Daniel Grant
# Version:	1.0.0
##############################################################

# Configuration
TO_EMAIL=
CMD_SENDMAIL=/usr/sbin/sendmail

log() {
  if [ "$1" = "ERROR" ]; then
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] [ERROR] $2"
  else
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] [INFO] $2"
  fi
}

log_info() {
  log "INFO" "$1"
}

log_error() {
  log "ERROR" "$1"
}

check_var() {
  if [ -z $2 ]; then
    log_error "$1 is not set"
    exit 1
  else
    log_info "Got $1 = $2"
  fi
}

check_cmd() {
  if [ -x $2 ]; then
    log_info "Got $1 = $2"
  else
    log_error "$2 does not exist"
    exit 1
  fi
}

check_file() {
  if [ -w $2 ]; then
    log_info "Got $1 = $2"
  else
    log_error "$2 does not exist or is not writeable"
    exit 1
  fi
}

insert_break() {
  echo "---------------------------------" >> $1
}

# Verify and log the configuration
check_var "TO_EMAIL" "$TO_EMAIL"
check_cmd "CMD_SENDMAIL" "$CMD_SENDMAIL"

# Create, verify and log the temporary file
OUTFILE=$(mktemp)
check_file "temporary file" $OUTFILE

# Report hostname and server uptime
echo "$(hostname -f): $(uptime --pretty)" >> $OUTFILE
insert_break $OUTFILE

# Report CPU percentage usage
echo "$(top -b -n 1 | grep ^%Cpu)" >> $OUTFILE
insert_break $OUTFILE

# Report system load averages
echo "Load Average: $(cat /proc/loadavg)" >> $OUTFILE
insert_break $OUTFILE

# Report memory consumption
echo "$(free -h)" >> $OUTFILE
insert_break $OUTFILE

# Report disk usage
echo "$(df -h)" >> $OUTFILE
insert_break $OUTFILE

# Report IO stats
echo "$(iostat -dmx | tail -n +3)" >> $OUTFILE
insert_break $OUTFILE

# Report currently logged in users
echo "Currently logged in users:\n$(who)" >> $OUTFILE
insert_break $OUTFILE

# Report last 10 logins
echo "Last 10 logins:\n$(last | head -10)" >> $OUTFILE
insert_break $OUTFILE

# Report top 10 processes by CPU
echo "Top 10 processes by CPU:\n$(ps -eo pcpu,pid,user,args | sort -k 1 -r | head -11)" >> $OUTFILE
insert_break $OUTFILE

# Report top 10 processes by memory
echo "Top 10 processes by memory:\n$(ps -eo pmem,pid,user,args | sort -k 1 -r | head -11)" >> $OUTFILE

# Dispatch the email
if [ -s "$OUTFILE" ]; then
  log_info "Emailing report to: $TO_EMAIL"
  (
    echo "Subject: [healthcheck report] $(hostname -f)"
    echo "To: $TO_EMAIL"
    echo ""
    cat $OUTFILE
  ) | $CMD_SENDMAIL $TO_EMAIL
else
  log_error "Temporary file '$OUTFILE' does not exist or is empty"
fi

# Delete the temporary file
log_info "Deleting temporary file '$OUTFILE'"
rm -f $OUTFILE

exit 0
