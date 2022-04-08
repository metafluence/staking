# Staking Token

This project defined the Metafluence Staking contract.

# Docs

 1) Owner`s ability to withdraw tokens from the contract. 
function withdraw(address payable addr, uint amount) external onlyOwner; 
 
The withdraw function just available for contract owner. The main reason that to move different staking campaign amounts to single staking pool if needed.  
This also brings security, because not all staked amounts staying in staked original wallets but could be transfered to cold wallets during staking time. 
 
 2) Owner`s ability to add and remove any stakings. 
function addStake(address _staker, uint256 _amount, uint256 _time) public onlyOwner; 
function removeStake(address _staker, uint _id) public onlyOwner 
 
These functions created for manamagement purposes for owner. The method can be called by Owner only.  
Some stakers accidentally transfer tokens to contract address directly, not throught the staking portal.  
To manage this types of problems, owner should have add and remove functionality to edit all records. 
 
 
 3) Owner`s ability to change status of the contract. 
function setStakeStatus(StakeStatus status) public onlyOwner; 
 
The set stake status function used for change Contract status one of the options: ACTIVE, PAUSED, COMPLETED. 
 
Users just can stake when contract status is ACTIVE.  
And their staking duration is not related to this any Statuses. Time is ticking in all statuses.  
COMPLETED status needed to owner if he want to stop this staking campaign, and create new ones.  
PAUSED status need for extreme situations to pause the specific contract, for example if we'll need upgrade smart contract.
