
### Steps to set up project

Add .env file into `solidity_project` directory
```
RESET_DB=false
PROVIDER_URL=http://localhost:8545
PROVIDER_WEBSOCKET_URL=ws://127.0.0.1:8545
CONTRACT_ADDRESS=0x9fe46736679d2d9a65f0992f2272de9f3c7fa6e0
CONTRACT_ABI_PATH=../artifacts/contracts/Will.sol/Will.json
EVENT_POOL_INTERVAL=500
EVENT_BLOCKS_TO_WAIT=0
EVENT_BLOCKS_TO_READ=0
```

Add .env file into `backend` directory
```
RESET_DB=true
PROVIDER_URL=http://localhost:8545
PROVIDER_WEBSOCKET_URL=ws://127.0.0.1:8545
CONTRACT_ADDRESS=0x9fe46736679d2d9a65f0992f2272de9f3c7fa6e0
CONTRACT_ABI_PATH=../../solidity_project/artifacts/contracts/Will.sol/Will.json
EVENT_POOL_INTERVAL=500
EVENT_BLOCKS_TO_WAIT=0
EVENT_BLOCKS_TO_READ=0
```

#### To compile contract:
`` cd solidity_project && npx hardhat compile ``

#### To start blockchain network:
`` npx hardhat node ``

#### To deploy contracts:
open new terminal window and enter ``npx hardhat run scripts/deploy.js --network localhost`` 

#### Update contract address in .env file
Copy and paste the contact address into .env file in both backend and solidity_project folder into the contract address field.

This is an example of what it looks like after starting and deploying the blockchain network
```
  Contract deployment: Will
  Contract address:    0x9fe46736679d2d9a65f0992f2272de9f3c7fa6e0
```

This is an example of the .env file
```
RESET_DB=true
PROVIDER_URL=http://localhost:XXX
PROVIDER_WEBSOCKET_URL=ws://127.0.0.1:8545
CONTRACT_ADDRESS=0x9fe46736679d2d9a65f0992f2272de9f3c7fa6e0
CONTRACT_ABI_PATH=../../solidity_project/artifacts/contracts/Will.sol/Will.json
EVENT_POOL_INTERVAL=500
EVENT_BLOCKS_TO_WAIT=0
EVENT_BLOCKS_TO_READ=0
```

#### To start backend:
``cd backend && npm start ``

#### To start test:
Run the following in /solidity_project
`` npx hardhat test ``



## File Structure

```
.
├── backend/                     # Backend API to interact with blockchain & mock data
│   ├── firebase/                # Functions to setup to firebase database
│   ├── routes/                  # API routes 
│   ├── services/                # Business logic for blockchain interaction and data management
│   └── services/                # Helper functions and utilities for backend operations
│
└── solidity_project/             # Smart contract development environment using Hardhat
    ├── README.md                 # Documentation for the Solidity project
    ├── contracts/                # Solidity smart contracts 
    ├── hardhat.config.js         # Hardhat configuration deployments
    ├── package.json              # Project dependencies and scripts
    ├── scripts/                  # Deployment and contract interaction scripts
    ├── test/                     # Unit tests for smart contracts
```

##### Testing github workflow locally
This is an example to test github cron job, you can run this job manually.
Install `act` with `brew install act` before attempting
Run the following in the root repository
```
act workflow_dispatch \
    -s FIREBASE_CREDENTIALS="$(cat backend/firebase/serviceAccountKey.json)" \
    -j fetch-data

```