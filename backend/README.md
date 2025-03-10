

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

## Government API
The Government API is the endpoint which our blockchain system should use to retrieve the death certificate as long as authorized credentials are provided. 

## Setting Up 
Please go to backend root folder, create a new file called ".env". Inside, add a "RESET_DB = true" or "RESET_DB = false" as needed. 
<br/>In addition, add the needed pdf inside data folder as well. 
<br/> type "npm install" on the backend folder to install necessary packages
<br/> type "npm start" to start backend localhost
