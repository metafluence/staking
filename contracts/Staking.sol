// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Metafluence.sol";
import "./IStakeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";


contract Staking is Initializable,IStakeable {
    Metafluence public token;
    address private _owner;

    modifier onlyOwner {
        require(msg.sender == _owner, "only owner has permission for this action.");
        _;
    }

    uint256 public totalSupplied;

    uint constant REWARD_PERCENTAGE  = 20;
    uint constant PENALTY_PERCENTAGE  = 30;
    uint constant REWARD_DEADLINE_DAYS = 30;
    uint constant REWARD_DEADLINE_SECONDS = 100;
    uint constant MAX_SUPPLIED = 20000000000000; //keep maximum supplied tokens count
    address constant TOKEN_CONTRACT_ADDRESS = 0xc39A5f634CC86a84147f29a68253FE3a34CDEc57; //Metafluence token address

    struct Staker {
        uint256 amount;
        uint256 reward;
        uint stakedAt;
    }

    mapping(address => Staker) public stakers;

    function initialize() public initializer {
        _owner = msg.sender;
        token = Metafluence(TOKEN_CONTRACT_ADDRESS);
    }

    /** add new staker */
    function stake(uint256 _amount) external override {

        require(totalSupplied +  _amount <= MAX_SUPPLIED, "reach MAX suplied amount.");

        Staker memory st = Staker(_amount, 0, block.timestamp);
        
        token.transferFrom(msg.sender, address(this), _amount);
        stakers[msg.sender] = st;
        totalSupplied += _amount;
        emit Stake(msg.sender, _amount);
    }

    function findStaker(address stakerAddr)
        external
        view
        returns (Staker memory)
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
    function claim() external override {
        uint256 balance = userBalance(address(this));
        uint256 reward = _calculateReward(msg.sender);
        require(balance > reward, "insufficent funds.");

        token.transfer(msg.sender, reward);
        _unstake(msg.sender);
    }

    /** unstake */
    function unstake(address staker) external override {
        _unstake(staker);
    }

    /** unstake internal */
    function _unstake(address _staker) internal {
        delete stakers[_staker];
        emit Unstake(msg.sender);
    }

    /** caluclate staker reward */
    function calculateReward(address _staker) external view override returns(uint256) {
        return _calculateReward(_staker);
    }
    /** caluclate staker reward internally */
    function _calculateReward(address _staker) internal view returns(uint256) {
        Staker memory staker = stakers[_staker];

        uint256 currentTime = block.timestamp;

        uint256 secondsStaked = currentTime - staker.stakedAt;

        //set penalty
        if (secondsStaked < REWARD_DEADLINE_SECONDS) {
            return staker.amount - (staker.amount * PENALTY_PERCENTAGE / 100);
        }


        return staker.amount + (staker.amount * REWARD_PERCENTAGE / 100);
    }

}
