// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IStakeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";


contract Staking is Initializable, IStakeable, OwnableUpgradeable {

    /** modifier check stake is available */
    modifier StakeAvailable(address _staker, uint256 _amount) {
        require(_amount >= MIN_STAKING_AMOUNT,  "staked amount must be greate or equal MIN_STAKING_AMOUNT stake value(2000)");
        require(totalStaked +  _amount <= POOL_MAX_SIZE, "reach POOL_MAX_SIZE.");
        require(_stakeStatus == StakeStatus.ACTIVE, "Stake status is not ACTIVE.");
        require(userTotalStakedAmount(_staker) + _amount <  MAX_STAKING_AMOUNT,  "reach MAX_STAKING_AMOUNT per wallet.");
        _;
    }

    IERC20Upgradeable public token;

    enum StakeStatus {ACTIVE, PAUSED, COMPLETED}

    StakeStatus public _stakeStatus;
    uint256 public totalStaked; // keeps total staking amount
    uint constant CODE_NOT_FOUND = 9999999; // keeps code about not founded stake. 

    // FOR 3 monthes staking
    // uint constant REWARD_PERCENTAGE  = 3; //reward percent
    // uint constant PENALTY_PERCENTAGE  = 30; //penalty percent

    // uint constant REWARD_DEADLINE_SECONDS = 3600 * 3; //stake time with seconds

    // uint constant POOL_MAX_SIZE = 5_000_000 * 10 ** 18; //keep maximum pool size
    // uint constant MIN_STAKING_AMOUNT = 2000 * 10 ** 18 ; //keep minimum staking amount per transaction
    // uint constant MAX_STAKING_AMOUNT = 250000 * 10 ** 18; //keep max staking amount per wallet
    
    // FOR 6 monthes staking
    // uint constant REWARD_PERCENTAGE  = 10; //reward percent
    // uint constant PENALTY_PERCENTAGE  = 35; //penalty percent

    // uint constant REWARD_DEADLINE_SECONDS = 3600 * 6; //stake time with seconds

    // uint constant POOL_MAX_SIZE = 10_000_000 * 10 ** 18; //keep maximum pool size
    // uint constant MIN_STAKING_AMOUNT = 2000 * 10 ** 18 ; //keep minimum staking amount per transaction
    // uint constant MAX_STAKING_AMOUNT = 500000 * 10 ** 18; //keep max staking amount per wallet

    // FOR 9 monthes staking
    // uint constant REWARD_PERCENTAGE  = 20; //reward percent
    // uint constant PENALTY_PERCENTAGE  = 40; //penalty percent

    // uint constant REWARD_DEADLINE_SECONDS = 3600 * 9; //stake time with seconds

    // uint constant POOL_MAX_SIZE = 15_000_000 * 10 ** 18; //keep maximum pool size
    // uint constant MIN_STAKING_AMOUNT = 2000 * 10 ** 18 ; //keep minimum staking amount per transaction
    // uint constant MAX_STAKING_AMOUNT = 750000 * 10 ** 18; //keep max staking amount per wallet

    // FOR 12 monthes staking
    uint constant REWARD_PERCENTAGE  = 36; //reward percent
    uint constant PENALTY_PERCENTAGE  = 45; //penalty percent

    uint constant REWARD_DEADLINE_SECONDS = 3600 * 12; //stake time with seconds
    
    uint constant POOL_MAX_SIZE = 20_000_000 * 10 ** 18; //keep maximum pool size
    uint constant MIN_STAKING_AMOUNT = 2000 * 10 ** 18 ; //keep minimum staking amount per transaction
    uint constant MAX_STAKING_AMOUNT = 1_000_000 * 10 ** 18; //keep max staking amount per wallet

    uint constant PENALTY_DIVISION_DAYS = 30;
    // wallet infos
    address constant TOKEN_CONTRACT_ADDRESS = 0xc39A5f634CC86a84147f29a68253FE3a34CDEc57; //Token contract address
    address payable staking_main_pool_wallet; // withdraw collected staking token to this wallet if needed

    // keeps staker info
    struct Staker {
        uint256 amount;
        uint256 reward;
        uint stakedAt;
    }

    mapping(address => Staker []) public stakers; // keeps all stakers
    
    function initialize() public initializer {
        __Ownable_init();
        token = IERC20Upgradeable(TOKEN_CONTRACT_ADDRESS);
        staking_main_pool_wallet = payable(0xC26392737eF87FD3e4eEFBD877feD88e89A0551F);
    }

    /** add new staker */
    function stake(uint256 _amount) external override StakeAvailable(msg.sender, _amount){        
        //check stake model hash enough sapce for new staking then set stake model as completed
        if (totalStaked == POOL_MAX_SIZE || POOL_MAX_SIZE - totalStaked < MIN_STAKING_AMOUNT) {
            _setStakeStatus(StakeStatus.COMPLETED);
        }

        Staker memory st = Staker(_amount, 0, block.timestamp);

        SafeERC20Upgradeable.safeTransferFrom(token, msg.sender, address(this), _amount);
        st.reward = _calcReward(st);
        stakers[msg.sender].push(st);
        totalStaked += _amount;
        emit Stake(msg.sender, _amount);
    }

        /** retrieve user stakes */
    function myStakes(address stakerAddr)
        external
        view
        returns (Staker [] memory)
    {        
        return stakers[stakerAddr];
    }
    
    /** find user total staked amount */
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

        (uint256 rewardedAmount, uint256 amount) = calculateTransferAmount(msg.sender, _id);

        require(balance > rewardedAmount, "insufficent funds.");

        SafeERC20Upgradeable.safeTransfer(token, msg.sender, rewardedAmount);

        totalStaked -= amount;
        _unstake(msg.sender, _id);
    }

    /** unstake remove user stake by given _id */
    function _unstake(address _staker, uint _id) internal {
        (, uint index) = getStakeById(_staker, _id);
        require (index < CODE_NOT_FOUND,  "can not find valid stake.");
        _remove(index);
        emit Claim(msg.sender);
    }

    /** caluclate staker claimable amount */
    function calculateTransferAmount(address _staker, uint _id) public view returns(uint256, uint256) {
        (Staker memory staker, uint index) = getStakeById(_staker, _id);

        if (index == CODE_NOT_FOUND) {
            return (0, 0);
        }

        uint256 currentTime = block.timestamp;

        uint256 secondsStaked = currentTime - staker.stakedAt;
        
        if (secondsStaked < REWARD_DEADLINE_SECONDS) {
            return (_calcPenalty(staker, secondsStaked), staker.amount);
        }


        return (_calcReward(staker), staker.amount);

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
        Staker memory st;
        return (st, CODE_NOT_FOUND);
    }

    /** remove user stake with given array index */
    function _remove(uint _index) internal {
        address me = msg.sender;
        require(_index < stakers[me].length, "index out of bound");

        for (uint i = _index; i < stakers[me].length - 1; i++) {
            stakers[me][i] = stakers[me][i + 1];
        }
        stakers[me].pop();
    }

    /** calculate staker reward */
    function _calcReward(Staker memory request) internal pure returns(uint) {
        return request.amount+ (request.amount * REWARD_PERCENTAGE / 100);
    }

    /** calculate staker penalty */
    function _calcPenalty(Staker memory request, uint secondStaked) internal pure returns(uint) {

        uint percent = PENALTY_PERCENTAGE - (PENALTY_PERCENTAGE / REWARD_DEADLINE_SECONDS * secondStaked);

        return request.amount - (request.amount * percent / 100);
    }

    /** withdraw contract balance to staking_main_pool_wallet */
    function withdraw(uint amount) external onlyOwner {
        token.approve(address(this), amount);
        SafeERC20Upgradeable.safeTransferFrom(token, address(this), staking_main_pool_wallet, amount);
        //todo emit withdraw
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
    function addStake(address _staker, uint256 _amount) public onlyOwner (_staker, _amount) {
        Staker memory st = Staker(_amount, 0, block.timestamp);
        st.reward = _calcReward(st);
        stakers[msg.sender].push(st);
        totalStaked += _amount;
        emit Stake(msg.sender, _amount);
    }

    /** remove stake by contract owner manually*/
    function removeStake(address _staker, uint _id) public onlyOwner {
        (, uint index) = getStakeById(_staker, _id);
        require (index < CODE_NOT_FOUND,  "can not find valid stake.");
        _remove(index);
        emit Claim(msg.sender);
    }

}
