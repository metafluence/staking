// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IStakeableSuperPool.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";


contract StakingSuperPool is Initializable, IStakeableSuperPool, OwnableUpgradeable {

    /** modifier check stake is available */
    modifier StakeAvailable(address _staker, uint256 _amount) {
        require(_amount >= MIN_STAKING_AMOUNT,  "staked amount must be great or equal to minimum staking amount");
        require(_stakeStatus == StakeStatus.ACTIVE, "Staking is not active");
        require(userTotalStakedAmount(_staker) + _amount <=  MAX_STAKING_AMOUNT,  "reached max staking amount per wallet");
        _;
    }

    IERC20Upgradeable public token;

    enum StakeStatus {ACTIVE, PAUSED, COMPLETED}

    StakeStatus public _stakeStatus;
    uint256 public totalStaked; // keeps total staking amount
    uint constant CODE_NOT_FOUND = 9999999; // keeps code about not founded stake. 

    // FOR 3 monthes staking
    uint constant REWARD_PERCENTAGE  = 10000; //reward percent
    uint constant PENALTY_PERCENTAGE  = 17; //penalty percent

    uint constant REWARD_DEADLINE_SECONDS = 3600; //3600 * 24 * 30 * 3; //stake time with seconds.

    uint constant MIN_STAKING_AMOUNT = 2000 * 10 ** 18 ; //keep minimum staking amount per transaction
    uint constant MAX_STAKING_AMOUNT = 250000 * 10 ** 18; //keep max staking amount per wallet

    // wallet infos
    address constant TOKEN_CONTRACT_ADDRESS = 0xa78775bba7a542F291e5ef7f13C6204E704A90Ba; //Token contract address

    // keeps staker info
    struct Staker {
        uint256 amount;
        uint256 reward;
        uint stakedAt;
        uint claimedAt;
        uint256 totalClaimed;
        uint256 claimable;
    }

    mapping(address => Staker []) public stakers; // keeps all stakers
    
    function initialize() public initializer {
        __Ownable_init();
        token = IERC20Upgradeable(TOKEN_CONTRACT_ADDRESS);
    }

    /** add new staker */
    function stake(uint256 _amount) external override StakeAvailable(msg.sender, _amount){        
        Staker memory st = Staker(_amount, 0, block.timestamp, block.timestamp, 0, 0);
        stakers[msg.sender].push(st);
        totalStaked += _amount;

        SafeERC20Upgradeable.safeTransferFrom(token, msg.sender, address(this), _amount);
        
        emit Stake(msg.sender, _amount);
    }

    /** retrieve user stakes 
    * it does not duplicate stakers. beacause stakers receive address,  uint256 and return single Staker model
    * myStakes returns array of Staker
    */
    function myStakes(address stakerAddr)
        public
        view
        returns (Staker [] memory)
    {
        Staker [] memory myAllStakes = stakers[stakerAddr];
        for(uint i = 0; i < myAllStakes.length; i++){
            myAllStakes[i].claimable = _calcReward(msg.sender, myAllStakes[i].stakedAt);
        }

        return myAllStakes;
    }
    
    /** find user total staked amount 
    * we do not prefer use external library. Also Solidity has not built in sum function.
    */
    function userTotalStakedAmount(address stakerAddr) public view returns(uint256) {
        uint256 total;
        Staker [] storage stakes = stakers[stakerAddr];
        for (uint i = 0; i < stakes.length; i++) {
            total += stakes[i].amount;
        }

        return total;
    }

    /** claim user token */
    function claim(uint _id) external override {
        require(_stakeStatus != StakeStatus.PAUSED, "Staking model PAUSED.");
        uint256 balance = token.balanceOf(address(this));

        uint256 amount = _calcReward(msg.sender, _id);

        require(amount > 0 , "no reward.");

        require(balance > amount, "insufficent funds.");

        SafeERC20Upgradeable.safeTransfer(token, msg.sender, amount);
        (, uint index) = getStakeById(msg.sender, _id);

        stakers[msg.sender][index].claimedAt = block.timestamp;
        stakers[msg.sender][index].totalClaimed += amount;
    }

    function claimAll(uint _id) external override{
        require(_stakeStatus != StakeStatus.PAUSED, "Staking model PAUSED.");
        uint256 balance = token.balanceOf(address(this));
        uint256 reward = _calcReward(msg.sender, _id);
        (uint256 finalAmountAfterPenalty, uint256 amount) = calculateTransferAmount(msg.sender, _id);
        uint256 totalAmount = finalAmountAfterPenalty + reward;
        require(balance > totalAmount, "insufficent funds.");

        totalStaked -= amount;
    
        (, uint index) = getStakeById(msg.sender, _id);
        stakers[msg.sender][index].claimedAt = block.timestamp;
        stakers[msg.sender][index].totalClaimed += reward;
        _unstake(msg.sender, _id);
        SafeERC20Upgradeable.safeTransfer(token, msg.sender, totalAmount);
        emit ClaimAll(msg.sender);
    }

    /** unstake remove user stake by given _id */
    function _unstake(address _staker, uint _id) internal {
        (, uint index) = getStakeById(_staker, _id);
        require (index < CODE_NOT_FOUND,  "can not find valid stake.");
        _remove(msg.sender, index);
        emit Claim(msg.sender);
    }

    /** caluclate staker claimable amount */
    function calculateTransferAmount(address _staker, uint _id) public view returns(uint256, uint256) {
        (Staker memory staker, uint index) = getStakeById(_staker, _id);

        if (index == CODE_NOT_FOUND) {
            return (0, 0);
        }

        return (_calcPenalty(staker), staker.amount);
    }

    /**
    * return staker by id
    */
    function getStakeById(address _staker, uint _id) internal view returns(Staker memory, uint) {

        Staker [] storage stakes = stakers[_staker];

        for (uint i = 0; i < stakes.length; i++) {
            if (stakes[i].stakedAt == _id) {
                return (stakes[i], i);
            }
        }

        //initalize empty Staker
        Staker memory st = Staker(0x0, 0, 0, 0, 0, 0);
        return (st, CODE_NOT_FOUND);
    }

    /** remove user stake with given array index 
    * we do not prefer use external library. Also Solidity has not built in remove function.
    */
    function _remove(address _staker, uint _index) internal {
        require(_index < stakers[_staker].length, "index out of bound");

        for (uint i = _index; i < stakers[_staker].length - 1; i++) {
            stakers[_staker][i] = stakers[_staker][i + 1];
        }
        stakers[_staker].pop();
    }

    /** calculate staker reward */
    function _calcReward(address _staker, uint _id) internal view returns(uint) {

        (Staker memory staker, uint index) = getStakeById(_staker, _id);

        if (index == CODE_NOT_FOUND) {
            return 0;
        }

        uint256 _amount = staker.amount * 10 ** 10;

        //how many hours staked
        uint _now = block.timestamp;
        uint _claimedAt = staker.claimedAt;

        uint256 hour = (_now - _claimedAt) / REWARD_DEADLINE_SECONDS;

        return _amount / REWARD_PERCENTAGE / 10 ** 10 * hour;
    }

    /** calculate staker penalty */
    function _calcPenalty(Staker memory request) internal pure returns(uint) {
        return request.amount - (request.amount * PENALTY_PERCENTAGE / 10 / 100);
    }

    /** withdraw contract balance to staking_main_pool_wallet */
    function withdraw(address payable addr, uint amount) external onlyOwner {
        SafeERC20Upgradeable.safeTransfer(token, addr, amount);
    }

    /**
    * set current staking model as finished
     */
    function setStakeStatus(StakeStatus status) public onlyOwner {
        _stakeStatus = status;
    }
    /** set stake status internally */
    function _setStakeStatus(StakeStatus status) internal {
        _stakeStatus = status;
    }
    /** add new stake by contract owner manually */
    function addStake(address _staker, uint256 _amount, uint256 _time) public onlyOwner {
        Staker memory st = Staker(_amount, 0, _time, 0, 0, 0);
        stakers[_staker].push(st);
        totalStaked += _amount;
        emit Stake(_staker, _amount);
    }

    /** remove stake by contract owner manually*/
    function removeStake(address _staker, uint _id) public onlyOwner {
        (Staker memory st, uint index) = getStakeById(_staker, _id);
        require (index < CODE_NOT_FOUND,  "can not find valid stake.");
        _remove(_staker, index);
        totalStaked -= st.amount;
        emit Claim(msg.sender);
    }
    
}
