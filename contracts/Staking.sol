// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IStakeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";


contract Staking is Initializable, IStakeable {
    IERC20Upgradeable public token;
    address private _owner;

    modifier onlyOwner {
        require(msg.sender == _owner, "only owner has permission for this action.");
        _;
    }

    enum StakeStatus {ACTIVE, PAUSED, COMPLETED}

    StakeStatus private _stakeStatus;
    uint256 public totalStaked; // keeps total staking amount
    uint constant CODE_NOT_FOUND = 9999999; // keeps code about not founded stake. 

    uint constant REWARD_PERCENTAGE  = 20; //reward percent
    uint constant PENALTY_PERCENTAGE  = 30; //penalty percent

    uint constant REWARD_DEADLINE_SECONDS = 3600 * 3; //stake time with seconds

    uint constant POOL_MAX_SIZE = 10_000_000 * 10 ** 18; //keep maximum pool size
    uint constant MIN_STAKING_AMOUNT = 2000 * 10 ** 18 ; //keep minimum staking amount per transaction
    uint constant MAX_STAKING_AMOUNT = 1_000_000 * 10 ** 18; //keep max staking amount per wallet

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
        _owner = msg.sender;
        token = IERC20Upgradeable(TOKEN_CONTRACT_ADDRESS);
        staking_main_pool_wallet = payable(0xC26392737eF87FD3e4eEFBD877feD88e89A0551F);
        _setStakeStatus(StakeStatus.ACTIVE);
    }

    /** add new staker */
    function stake(uint256 _amount) external override {
        require(_amount >= MIN_STAKING_AMOUNT,  "staked amount must be greate or equal MIN_STAKING_AMOUNT stake value(2000)");
        require(totalStaked +  _amount <= POOL_MAX_SIZE, "reach POOL_MAX_SIZE.");
        require(_stakeStatus == StakeStatus.ACTIVE, "Stake status is not ACTIVE.");
        require(userTotalStakedAmount(msg.sender) + _amount <  MAX_STAKING_AMOUNT,  "reach MAX_STAKING_AMOUNT per wallet.");
        
        //set stake model status as completed if reached POOL_MAX_SIZE
        if (totalStaked == POOL_MAX_SIZE || POOL_MAX_SIZE - totalStaked > MIN_STAKING_AMOUNT) {
            _setStakeStatus(StakeStatus.COMPLETED);
        }

        Staker memory st = Staker(_amount, 0, block.timestamp);
        
        token.transferFrom(msg.sender, address(this), _amount);
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

    /** retrieve user balance from token contract */
    function userBalance(address addr) public view returns(uint256) {
        return token.balanceOf(addr);
    }
    
    /** find user total staked amount */
    function userTotalStakedAmount(address stakerAddr) public view returns(uint256) {
        uint256 total;
        Staker [] memory stakes = stakers[stakerAddr];
        for (uint i = 0; i < stakes.length; i++) {
            total += stakes[i].amount;
        }

        return total;
    }

    /** approve staking contract at token contract */
    function _approve(address _from, uint256 _amount) internal {
        token.approve(_from, _amount);
    }
    
    /** claim user token */
    function claim(uint _id) external override {
        uint256 balance = userBalance(address(this));

        (uint256 rewardedAmount, uint256 amount) = calculateTransferAmount(msg.sender, _id);

        require(balance > rewardedAmount, "insufficent funds.");

        token.transfer(msg.sender, rewardedAmount);

        totalStaked -= amount;
        _unstake(msg.sender, _id);
    }

    /** unstake remove user stake by given _id */
    function _unstake(address _staker, uint _id) internal {
        (, uint index) = getStakeById(_staker, _id);
        require (index < CODE_NOT_FOUND,  "can not find valid stake.");
        _remove(index);
        emit Unstake(msg.sender);
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

        Staker [] memory stakes = stakers[_staker];

        for (uint i = 0; i < stakes.length; i++) {
            if (stakes[i].stakedAt == _id) {
                return (stakes[i], i);
            }
        }
        Staker memory st;
        return (st, CODE_NOT_FOUND);
    }

    /** remove user stake with given array index */
    function _remove(uint _index) public {
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
        _approve(address(this), amount);
        token.transferFrom(address(this), staking_main_pool_wallet, amount);
        //todo emit withdraw
    }

    /**
    * set current staking model as finished
     */
    function _setStakeStatus(StakeStatus status) public onlyOwner {
        _stakeStatus = status;
    }
}
