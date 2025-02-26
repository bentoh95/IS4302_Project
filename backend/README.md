

### Start cron job (Mac)
1. Navigate into /utils
    ``` cd utils ```
2. Give permission ```chmod +x add_cron.sh ```
3. Run add_cron.sh ```./add_cron.sh```

If successful, cron.log file appears within a minute and success message appears. This cronjob runs the entire cron.js file.


### Stop cron job (Mac)
1. Give permission ```chmod +x stop_cron.sh ```
2. Run stop_cron.sh ```./stop_cron.sh```

<br /> 

Useful commands: 
<br /> ```crontab -l```: check curr running cronjobs
<br /> ```crontab -e```: edit cronjobs manually
