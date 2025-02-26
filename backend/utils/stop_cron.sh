#!/bin/bash

### FINDING PATH TO PROJECT
DIR_PATH="$(pwd)"
CRON_PATH="$DIR_PATH/cron.js"
CRON_LOG="$DIR_PATH/cron.log"

### FINDING NODE LOCATION
NODE_LOCATION="$(which node)"

### SETTING CRON SCHEDULE
CRONTAB_SCHEDULE="*/1 * * * *" # Every minute

### CRON JOB FOR CHECKING DEATH
CRON_JOB1="$CRONTAB_SCHEDULE $NODE_LOCATION $CRON_PATH checkDeath >> $CRON_LOG 2>&1"
### CRON JOB FOR DISTRIBUTING ASSETS
CRON_JOB2="$CRONTAB_SCHEDULE $NODE_LOCATION $CRON_PATH distributeAssets >> $CRON_LOG 2>&1"

### REMOVE CRON JOBS
echo "Stopping scheduled cron jobs..."

# Create a temporary crontab without the jobs
(crontab -l 2>/dev/null | grep -v -F "$CRON_JOB1" | grep -v -F "$CRON_JOB2") | crontab -

echo "Cron jobs removed successfully!"
