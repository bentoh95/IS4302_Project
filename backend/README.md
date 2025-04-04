

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
1. Please go to backend root folder, create a new file called ".env". Add the code below in the .env file
```shell
RESET_DB = true
PROVIDER_URL=http://localhost:8545
PROVIDER_WEBSOCKET_URL=ws://127.0.0.1:8545
CONTRACT_ADDRESS=0x5FbDB2315678afecb367f032d93F642f64180aa3 //might be different for different user, check in the npx hardhat node print
CONTRACT_ABI_PATH=../artifacts/contracts/Will.sol/Will.json
EVENT_POOL_INTERVAL=500
EVENT_BLOCKS_TO_WAIT=0
EVENT_BLOCKS_TO_READ=0
#set it to false so it does not reset the database for every reload
```
2. Add the pdf file (death certificate) inside data folder
3. Type this in terminal
```shell
npm install
npm start
```
