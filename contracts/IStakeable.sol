// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * IStake interface display required methods any Staker smart contracts
 */
interface IStakeable {
    function stake(uint256 _amount) external;
    function unstake(address staker) external;
    function calculateReward(address _staker) external view returns(uint256);
    function claim() external;

    event Stake(address indexed _staker, uint256 _amount);
    event Unstake(address indexed _staker);
}