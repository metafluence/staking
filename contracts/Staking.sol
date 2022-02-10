// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Metafluence.sol";
import "./IStakeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";


contract Staking is Initializable, IStakeable {
    Metafluence public token;
    address private _owner;

    modifier onlyOwner {
        require(msg.sender == _owner, "only owner has permission for this action.");
        _;
    }

    uint256 public totalSupplied;
    uint constant CODE_NOT_FOUND = 9999999;
    uint constant REWARD_PERCENTAGE  = 20; //reward percent
    uint constant PENALTY_PERCENTAGE  = 30; //penalty percent
    uint constant REWARD_DEADLINE_DAYS = 30; //stake time with days
    uint constant REWARD_DEADLINE_SECONDS = 100; //stake time with seconds
    uint constant MAX_SUPPLIED = 20000000000000; //keep maximum supplied tokens count
    uint constant MIN_SUPPLIED = 5000; //keep minimum amount of supplied token
    address constant TOKEN_CONTRACT_ADDRESS = 0xc39A5f634CC86a84147f29a68253FE3a34CDEc57; //Metafluence token address


    struct Staker {
        uint256 amount;
        uint256 reward;
        uint stakedAt;
    }

    mapping(address => Staker []) public stakers;

    function initialize() public initializer {
        _owner = msg.sender;
        token = Metafluence(TOKEN_CONTRACT_ADDRESS);
    }

    /** add new staker */
    function stake(uint256 _amount) external override {
        require(_amount >= MIN_SUPPLIED,  "staked amount must be greate or equal MIN_SUPPLIED stake value(5000)");
        require(totalSupplied +  _amount <= MAX_SUPPLIED, "reach MAX suplied amount. (20000000000000)");

        Staker memory st = Staker(_amount, 0, block.timestamp);
        
        token.transferFrom(msg.sender, address(this), _amount);
        st.reward = _calcReward(st);
        stakers[msg.sender].push(st);
        totalSupplied += _amount;
        emit Stake(msg.sender, _amount);
    }

    function findStaker(address stakerAddr)
        external
        view
        returns (Staker [] memory)
    {        
        return stakers[stakerAddr];
    }

    function userBalance(address addr) public view returns(uint256) {
        return token.balanceOf(addr);
    } 

    function approve(address _from, uint256 _amount) external {
        token.approve(_from, _amount);
    }
    
    function contAddr() external view returns(address) {
        return address(this);
    }

    /** claim user token */
    function claim(uint _id) external override {
        uint256 balance = userBalance(address(this));
        uint256 amount = calculateTransferAmount(msg.sender, _id);
        require(balance > amount, "insufficent funds.");

        token.transfer(msg.sender, amount);
        _unstake(msg.sender, _id);
    }

    /** unstake internal */
    function _unstake(address _staker, uint _id) internal {
        (, uint index) = getStakeById(_staker, _id);
        require (index < CODE_NOT_FOUND,  "can not find valid stake.");
        _remove(index);
        emit Unstake(msg.sender);
    }

    /** caluclate staker reward internally */
    function calculateTransferAmount(address _staker, uint _id) public view returns(uint256) {
        (Staker memory staker, uint index) = getStakeById(_staker, _id);

        if (index == CODE_NOT_FOUND) {
            return 0;
        }

        uint256 currentTime = block.timestamp;

        uint256 secondsStaked = currentTime - staker.stakedAt;

        
        if (secondsStaked < REWARD_DEADLINE_SECONDS) {
            return _calcPenalty(staker);
        }


        return _calcReward(staker);

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

    function _remove(uint _index) public {
        address me = msg.sender;
        require(_index < stakers[me].length, "index out of bound");

        for (uint i = _index; i < stakers[me].length - 1; i++) {
            stakers[me][i] = stakers[me][i + 1];
        }
        stakers[me].pop();
    }

        /**
    * caclulate any staking model reward which implement IStakable interface
    */
    function _calcReward(Staker memory request) internal pure returns(uint) {
        return request.amount+ (request.amount * REWARD_PERCENTAGE / 100);
    }

    /**
    * caclulate any staking model penalty which implement IStakable interface
    */
    function _calcPenalty(Staker memory request) internal pure returns(uint) {
        return request.amount - (request.amount * PENALTY_PERCENTAGE / 100);
    }
}
