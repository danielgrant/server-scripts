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
# report_bandwidth.sh
#
# Script that, using vnstat, reports the daily, weekly or
# monthly bandwidth usage for a given server.
#
# Author:       Daniel Grant
# Version:  1.0.0
##############################################################

# Configuration
MODE=weekly
TO_EMAIL=
CMD_VNSTAT=/usr/bin/vnstat
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
  if [ -z "$2" ]; then
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

# Verify and log the configuration
check_var "TO_EMAIL" $TO_EMAIL
check_cmd "CMD_VNSTAT" $CMD_VNSTAT
check_cmd "CMD_SENDMAIL" $CMD_SENDMAIL

# Create, verify and log the temporary file
OUTFILE=$(mktemp)
check_file "temporary file" $OUTFILE

# Determine the vnstat command and parameters
if [ "$MODE" = "daily" ]; then
  VNSTAT_PARAM="$CMD_VNSTAT --days | grep $(date --date="1 day ago" +"%x")"
else
  if [ "$MODE" = "weekly" ]; then
    VNSTAT_PARAM="$CMD_VNSTAT --weeks | grep \"last week\""
  else
    if [ "$MODE" = "monthly" ]; then
      VNSTAT_PARAM="$CMD_VNSTAT --months | grep \"$(date --date="1 month ago" +"%b '%y")\""
    else
      log "ERROR" "Invalid MODE, must be one of 'daily', 'weekly' or 'monthly'"
      exit 1
    fi
  fi
fi

# Execute vnstat and process the output
log_info "Executing: $VNSTAT_PARAM"
eval $VNSTAT_PARAM > $OUTFILE

# Dispatch the email
if [ -s "$OUTFILE" ]; then
  log_info "Emailing report to: $TO_EMAIL"
  (
    echo "Subject: [bandwidth report] $(hostname -f) - $MODE report"
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
