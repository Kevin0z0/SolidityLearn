//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;
import "hardhat/console.sol";

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

    uint256 deploymentTimeStamp;
    uint256 lockTime;

    address erc20Address;
    bool public getFundSuccess = false;

    constructor(uint256 _locktime){
        // sepolia test net
        dataFeed = AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        owner = msg.sender;
        deploymentTimeStamp = block.timestamp;
        lockTime = _locktime;
    }

    function fund() external payable { //payable 收款
        require(convertEthToUsd(msg.value) >= MINIMUM_VALUE, "Send More ETH!");
        require(block.timestamp < deploymentTimeStamp + lockTime, "Windows is closed");
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

    function getFund() external windowClose onlyOwner {
        require(convertEthToUsd(address(this).balance) >= TARGET, "Target is not reached");
        
        //三种转账方式
        //transfer： transfer ETH and revert if tx failed
        // payable(msg.sender).transfer(address(this).balance);

        //send: return bool
        // bool success = payable(msg.sender).send(address(this).balance);
        // console.log(success);

        //call
        bool success;
        (success, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(success, "transfer is successed");
        fundersToAmount[msg.sender] = 0;
        getFundSuccess = true;
    }

    function transferOwnership(address newOwner) public onlyOwner{
        owner = newOwner;
    }

    function refund() external windowClose{
        require(convertEthToUsd(address(this).balance) < TARGET, "Target is reached");
        require(fundersToAmount[msg.sender] != 0, "there is no fund for you");
        bool success;
        (success, ) = payable(msg.sender).call{value: fundersToAmount[msg.sender]}("");
        require(success, "transfer tx failed");
        fundersToAmount[msg.sender] = 0;
    }

    function setErc20Addr(address _erc20Addr) public onlyOwner{
        erc20Address = _erc20Addr;
    }

    function setFunderToAmount(address funder, uint256 amountToUpdate) external {
        require(msg.sender == erc20Address, "You do not have permission to call this function");
        fundersToAmount[funder] = amountToUpdate;
    }

    modifier windowClose(){
        require(block.timestamp >= deploymentTimeStamp + lockTime, "windows is not closed");
        _;
    }

    modifier onlyOwner(){
        require(msg.sender == owner, "This function can only be called by owner");
        _;
    }
}