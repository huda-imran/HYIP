//TODO:lock pvgn
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;


import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract HYIP is Ownable {
    using SafeMath for uint256;
    // Token used for deposits and withdrawals
    IERC20 private usdt;
    // Token used for airdrops
    IERC20 private pvgn;
    //total fee to be claimed
    uint256 public feeToBeClaimed;
    // Fee for depositing on farming pools
    uint256 constant private DEPOSIT_FEE_BPS = 500; //5% = 500 bps
    // Fee for withdrawing to wallet
    uint256 constant private WITHDRAWAL_FEE_BPS = 1000; //10% = 1000 bps
    // 4.2 PVGN tokens per USDT invested
    uint256 public constant REWARD_PER_TOKEN = 4.2 * 10 ** 18; // 4.2 rewards per token deposited

    // Enum to specify garden tiers
    enum GardenTier { Rookie, Pro, Master }
    enum PaymentMode { eth, usdt }
    
    // Struct to represent a user's investment in a garden
    struct Pool {
        uint256 minimumInvestment;
        uint256 maximumInvestment;
        uint256 balanceLockedTime;
        uint256 dailyProfitBps;
        uint256 monthlyProfitBps;
        uint256 totalROIBps;
        bool canReturnInvestment;
    }
    struct Investment {
        address referrer;
        uint256 startTime;
        uint256 endTime;
        uint256 lastClaimTime;
        PaymentMode paymentMode;
        uint256 amount;
    }
    Pool public rookiePool = Pool(50*10**18, 25000*10**18, 90 days, 40, 1200, 13600, true);
    Pool public proPool = Pool(1000*10**18, 25000*10**18, 180 days, 46, 1400, 18400, true);
    Pool public masterPool = Pool(1000*10**18, 85000*10**18, 270 days, 75, 2270, 20400, false);
    
    //Mapping of a user's investments in each garden
    mapping(address => mapping(GardenTier => Investment)) public investments;
    mapping(address => uint256) public referrerRewards;
    mapping(address => mapping (address => bool)) public affiliates;
    mapping(address => uint256) public affiliateCount;

    //events
    event Invested(address indexed investor, GardenTier indexed pool, uint256 amount);
    event StakeClaimed(address indexed investor, GardenTier indexed pool, uint256 amount);
    event FeesClaimed(uint256 amount, uint256 timestamp);
    event ReferrerRewardClaimed(uint256 amount, uint256 timestamp);
    event InvestmentWithdrawn( address indexed user, GardenTier indexed garden, uint256 amount, uint256 timestamp);


    constructor(address _usdt, address _pvgn) {
        require( _usdt != address(0) && _pvgn != address(0), "Invalid address");
        usdt = IERC20(_usdt);
        pvgn = IERC20(_pvgn);  
    }

    function invest(GardenTier _pool, uint256 _amount, address _referrer) payable external {
        //investment in eth
        if(msg.value > 0) {
            require(msg.value == _amount, "Incorrect payment amount");
            //TODO:Need to complete the eth part of payments
        }
        //investment in usdt
        else {
            require(usdt.allowance(_msgSender(), address(this)) >= _amount, "Not enough allowance granted");
            require(usdt.balanceOf(_msgSender()) >= _amount, "Insufficient balance");

            Investment memory previousInvestment;
            Pool memory pool;
            if(_pool == GardenTier.Rookie) {
                previousInvestment = investments[_msgSender()][GardenTier.Rookie];
                pool = rookiePool;
            }
            else if(_pool == GardenTier.Pro) {
                previousInvestment = investments[_msgSender()][GardenTier.Pro];
                pool = proPool;
            }
            else if(_pool == GardenTier.Master) {
                previousInvestment = investments[_msgSender()][GardenTier.Master];
                pool = masterPool;
            }
            else {
                revert("Invalid pool name");
            }
            require(_amount >= pool.minimumInvestment && _amount <= pool.maximumInvestment, "Invalid amount for the Pool");
            require(_referrer == address(0) || previousInvestment.referrer == address(0), "Only one referrer for one type of pool");
            //calculate deposit fees
            uint256 fee = getFee(_amount, DEPOSIT_FEE_BPS); 
            feeToBeClaimed += fee;
            uint256 amountInvested = _amount - fee;
            console.log("fee", fee);
            console.log("amount invested",amountInvested);

            //check user's investment in rookie garden
                
            require (amountInvested + previousInvestment.amount <= pool.maximumInvestment, "Total investment exceeds maximum investment");

            Investment memory investment;
            if(previousInvestment.amount == 0) {
                    investment = Investment(_referrer ,block.timestamp, block.timestamp + pool.balanceLockedTime, 0, PaymentMode.usdt, amountInvested);   
            }
            else {
                if(previousInvestment.referrer == address(0)){
                    investment = Investment(_referrer, previousInvestment.startTime, block.timestamp + pool.balanceLockedTime, previousInvestment.lastClaimTime, PaymentMode.usdt, amountInvested + previousInvestment.amount);
                }
                else {
                    investment = Investment(previousInvestment.referrer, previousInvestment.startTime, block.timestamp + pool.balanceLockedTime, previousInvestment.lastClaimTime, PaymentMode.usdt, amountInvested + previousInvestment.amount);
                }
                
            }
            investments[_msgSender()][_pool] = investment;
            uint256 referrerFee;
            if(_referrer != address(0)) {
                referrerFee = getFee(_amount, WITHDRAWAL_FEE_BPS);
                referrerRewards[_referrer] = referrerRewards[_referrer] + referrerFee;
                if(!affiliates[_referrer][_msgSender()]){
                    affiliates[_referrer][_msgSender()] = true;
                    affiliateCount[_referrer] += 1;
                }

            }

            //charge deposit fees
            require(usdt.transferFrom(_msgSender(), address(this), _amount), "Deposit fee transfer failed");

            //calculate the amount of pvgn to transfer to the investor
            //transfer pvgn to the investor
            distributePvgn(_msgSender(), _amount);
        }
        emit Invested(_msgSender(), _pool, _amount);
    }

    function claimStake(GardenTier _pool) external {
        Investment memory investment;
        Pool memory pool;
        if(_pool == GardenTier.Rookie) {
            investment = investments[_msgSender()][GardenTier.Rookie];
            pool = rookiePool;
        }
        else if(_pool == GardenTier.Pro) {
            investment = investments[_msgSender()][GardenTier.Pro];
            pool = proPool;
        }
        else if(_pool == GardenTier.Master) {
            investment = investments[_msgSender()][GardenTier.Master];
            pool = masterPool;
        }
        else {
            revert("Invalid pool name");
        }
        
        require(investment.startTime != 0, "You have no investments in Pool");
        require(block.timestamp - investment.startTime >= 86400*2, "Rewards are claimable after 2 days of initial investment");
        require(block.timestamp - investment.lastClaimTime >= 86400, "Please wait for 24 hrs to collect next claim");
        
        //calculate time difference 
        uint256 totalDayCount;
        if(investment.lastClaimTime == 0) 
            totalDayCount = getTimeDiff(investment.startTime, block.timestamp);
        else
            totalDayCount = getTimeDiff(investment.lastClaimTime, block.timestamp);

        //calculate reward
        uint256 claimableStake = totalDayCount.mul(getFee(investment.amount, pool.dailyProfitBps));
        console.log("claimable stake", claimableStake);
        investments[_msgSender()][GardenTier.Rookie].lastClaimTime = block.timestamp;
        console.log("balance ", usdt.balanceOf(address(this)));
        require(usdt.balanceOf(address(this)) >= claimableStake, "Contract has insufficient USDT balance");
        uint256 fee = getFee(claimableStake, WITHDRAWAL_FEE_BPS); 
        feeToBeClaimed += fee;
        require(usdt.transfer(_msgSender(), claimableStake - fee), "Stake transfer failed");
        emit StakeClaimed(_msgSender(), _pool, claimableStake - fee);
        
    }

    function withdrawInvestment(GardenTier _pool) external {
        Pool memory pool;
        Investment memory investment;
        if(_pool == GardenTier.Rookie) {
            investment = investments[_msgSender()][GardenTier.Rookie];
            pool = rookiePool;
        }
        else if(_pool == GardenTier.Pro) {
            investment = investments[_msgSender()][GardenTier.Pro];
            pool = proPool;
        }
        else if(_pool == GardenTier.Master) {
            investment = investments[_msgSender()][GardenTier.Master];
            pool = masterPool;
        }
        else {
            revert("Invalid pool name");
        }
        require(investment.startTime != 0, "You have no investments in the Pool");
        require(pool.canReturnInvestment && investment.endTime <= block.timestamp, "You cannot withdraw investment");
        require(usdt.balanceOf(address(this)) >= investment.amount, "Contract has insufficient USDT balance");
        require(usdt.transfer(_msgSender(), investment.amount), "Fee transfer failed");
        emit InvestmentWithdrawn(_msgSender(), _pool, investment.amount, block.timestamp);
        
    }

    function claimFee() external onlyOwner {
        require(feeToBeClaimed > 0, "No funds for you to claim");
        require(usdt.balanceOf(address(this)) >= feeToBeClaimed, "Contract has insufficient USDT balance");
        require(usdt.transfer(_msgSender(), feeToBeClaimed), "Fee transfer failed");
        emit FeesClaimed(feeToBeClaimed, block.timestamp);
        feeToBeClaimed = 0;
    }

    function claimReferrerReward() external {
        require(referrerRewards[_msgSender()] > 0, "No funds for you to claim");
        require(usdt.balanceOf(address(this)) >= referrerRewards[_msgSender()], "Contract has insufficient USDT balance");
        require(usdt.transfer(_msgSender(), referrerRewards[_msgSender()]), "Fee transfer failed");
        emit ReferrerRewardClaimed(referrerRewards[_msgSender()], block.timestamp);
        referrerRewards[_msgSender()] = 0;
    }

    function getFee(uint256 _amount, uint256 _bps) private pure returns (uint256) {
        require((_amount.mul(_bps)) >= 10000);
        return _amount.mul(_bps).div(10000);
    }

    function distributePvgn(address _to, uint256 _amountInvested) private {
        //calculate pvgn to distribute
        //420 pvgn for 100$
        uint256 pvgnAmount = _amountInvested.div(10**18).mul(REWARD_PER_TOKEN);
        console.log(pvgnAmount);
        console.log(pvgn.balanceOf(address(this)));
        require(pvgn.balanceOf(address(this)) >= pvgnAmount, "Insufficient PVGN balance in the contract");
        require(pvgn.transfer(_to, pvgnAmount), "PVGN transfer failed");
    }

    function getTimeDiff(uint256 _startTime, uint256 _endTime) private pure returns (uint256) {
        require(_endTime > _startTime, "Invalid end time");
        uint256 diffInSeconds = _endTime.sub(_startTime);
        uint256 diffInDays = diffInSeconds.div(86400); // 86400 seconds in a day
        return diffInDays;
    }
    
    function getNextClaimableStake(GardenTier _pool, address _user) external view returns (uint256)
    {   
        Investment memory investment;
        Pool memory pool;
        if(_pool == GardenTier.Rookie) {
            investment = investments[_user][GardenTier.Rookie];
            pool = rookiePool;
        }
        else if(_pool == GardenTier.Pro) {
            investment = investments[_user][GardenTier.Pro];
            pool = proPool;
        }
        else if(_pool == GardenTier.Master) {
            investment = investments[_user][GardenTier.Master];
            pool = masterPool;
        }
        else {
            revert("Invalid pool name");
        }
        
        if(investment.startTime == 0){
            return 0;
        }
        //calculate time difference 
        uint256 totalDayCount;
        if(investment.lastClaimTime == 0) 
            totalDayCount = 2;
        else
            totalDayCount = 1;

        //calculate reward
        uint256 claimableStake = totalDayCount.mul(getFee(investment.amount, pool.dailyProfitBps));
        uint256 fee = getFee(claimableStake, WITHDRAWAL_FEE_BPS); 
        return claimableStake - fee;
    }
    function getClaimableStake(GardenTier _pool, address _user) external view returns (uint256)
    {   
        Investment memory investment;
        Pool memory pool;
        if(_pool == GardenTier.Rookie) {
            investment = investments[_user][GardenTier.Rookie];
            pool = rookiePool;
        }
        else if(_pool == GardenTier.Pro) {
            investment = investments[_user][GardenTier.Pro];
            pool = proPool;
        }
        else if(_pool == GardenTier.Master) {
            investment = investments[_user][GardenTier.Master];
            pool = masterPool;
        }
        else {
            revert("Invalid pool name");
        }
        
        if(investment.startTime != 0 || block.timestamp - investment.startTime >= 86400*2 || block.timestamp - investment.lastClaimTime >= 86400){
            return 0;
        }
        // require(investment.startTime != 0, "You have no investments in Pool");
        // require(block.timestamp - investment.startTime >= 86400*2, "Rewards are claimable after 2 days of initial investment");
        // require(block.timestamp - investment.lastClaimTime >= 86400, "Please wait for 24 hrs to collect next claim");
        
        //calculate time difference 
        uint256 totalDayCount;
        if(investment.lastClaimTime == 0) 
            totalDayCount = getTimeDiff(investment.startTime, block.timestamp);
        else
            totalDayCount = getTimeDiff(investment.lastClaimTime, block.timestamp);

        //calculate reward
        uint256 claimableStake = totalDayCount.mul(getFee(investment.amount, pool.dailyProfitBps));
        uint256 fee = getFee(claimableStake, WITHDRAWAL_FEE_BPS); 
        return claimableStake - fee;
    }
}