//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

// 1. 创建一个收款函数
// 2. 记录投资人并且查看
// 3. 在锁定期内，达到目标值，生产商可以提款
// 4. 在锁定期内，没有达到目标值，投资人可以退款


contract FundMe{
    AggregatorV3Interface internal dataFeed;

    mapping (address => uint256) public fundersToAmount;

    uint256 constant MINIMUM_VALUE = 100 * 10 ** 18;  //USD

    uint256 constant TARGET = 1000 * 10 ** 18;

    address public owner;

    constructor(){
        // sepolia test net
        dataFeed = AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        owner = msg.sender;
    }

    function fund() external payable { //payable 收款
        require(convertEthToUsd(msg.value) >= MINIMUM_VALUE, "Send More ETH!");
        fundersToAmount[msg.sender] = msg.value;
    }

    function getChainlinkDataFeedLatestAnswer() public view returns (int) {
        // prettier-ignore
        (
            /* uint80 roundId */,
            int256 answer,
            /*uint256 startedAt*/,
            /*uint256 updatedAt*/,
            /*uint80 answeredInRound*/
        ) = dataFeed.latestRoundData();
        return answer;
    }

    function convertEthToUsd(uint256 ethAmount) internal view returns (uint256){
        uint256 ethPrice = uint256(getChainlinkDataFeedLatestAnswer());
        return ethAmount * ethPrice / (10 ** 8);
    }

    function getFund() external {
        require(convertEthToUsd(address(this).balance) >= TARGET, "Target is not reached");
        require(msg.sender == owner, "This function can only be called by owner");
        //三种转账方式
        //transfer： transfer ETH and revert if tx failed
        payable(msg.sender).transfer(address(this).balance);
        //send: 
        //call
    }

    function transferOwnership(address newOwner) public{
        require(msg.sender == owner, "This function can only be called by owner");
        
        owner = newOwner;
    }
}