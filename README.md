
Navigate into blockchain project folder before testing

``` cd /solidity_project ```

#### To compile contract:
`` npx hardhat compile ``

#### To start blockchain network:
`` npx hardhat node ``

#### To deploy contracts:
open new terminal window and enter ``npx hardhat run scripts/deploy.js --network localhost`` 

## File Structure

```
.
├── backend/                     # Backend API to interact with blockchain & mock data
│   ├── data/                    # JSON-based mock database 
│   ├── routes/                  # API routes 
│   ├── services/                # Business logic for blockchain interaction and data management
│   └── utils/                   # Helper functions and utilities for backend operations
│
└── solidity_project/             # Smart contract development environment using Hardhat
    ├── README.md                 # Documentation for the Solidity project
    ├── contracts/                # Solidity smart contracts 
    ├── hardhat.config.js         # Hardhat configuration 
    ├── ignition/                  deployments
    ├── node_modules/              # Installed dependencies (auto-generated)
    ├── package.json               # Project dependencies and scripts
    ├── scripts/                   # Deployment and contract interaction scripts
    ├── test/                      # Unit tests for smart contracts
```