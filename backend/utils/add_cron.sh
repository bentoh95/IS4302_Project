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
echo "Currently testing checkDeath()"
CRON_JOB1="$CRONTAB_SCHEDULE $NODE_LOCATION $CRON_PATH checkDeath >> $CRON_LOG 2>&1"

# CHECK EXISTENCE IF NOT ADD
(crontab -l 2>/dev/null | grep -F "$CRON_JOB1") && echo "Cron job for checkDeath() already exists." || (
    (crontab -l 2>/dev/null; echo "$CRON_JOB1") | crontab -
    echo "Cron job for checkDeath() added successfully."
)

### CRON JOB FOR DISTRIBUTING ASSETS
echo "Currently testing distributeAssets()"
CRON_JOB2="$CRONTAB_SCHEDULE $NODE_LOCATION $CRON_PATH distributeAssets >> $CRON_LOG 2>&1"

# CHECK EXISTENCE IF NOT ADD
(crontab -l 2>/dev/null | grep -F "$CRON_JOB2") && echo "Cron job for distributeAssets() already exists." || (
    (crontab -l 2>/dev/null; echo "$CRON_JOB2") | crontab -
    echo "Cron job for distributeAssets() added successfully."
)

