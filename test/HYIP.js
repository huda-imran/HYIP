const {time, loadFixture} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { ethers, network } = require("hardhat");

describe("HYIP contract", function () {
  const GardenTier = { Rookie: 0, Master: 1, Pro: 2 };
  let poolContract;
  let usdtToken;
  let pvgnToken;
  let owner;
  let user;
  before(async function () {
    [owner, user] = await ethers.getSigners();
    const UsdtToken = await ethers.getContractFactory("MyToken");
    usdtToken = await UsdtToken.connect(user).deploy("usdtToken", "USDT");
    await usdtToken.deployed();
    const PvgnToken = await ethers.getContractFactory("MyToken");
    pvgnToken = await PvgnToken.connect(owner).deploy("pvgnToken", "PVGN");
    await pvgnToken.deployed();
    const PoolContract = await ethers.getContractFactory("HYIP");
    poolContract = await PoolContract.connect(owner).deploy(usdtToken.address, pvgnToken.address);
    await poolContract.deployed();
  

    //mint and lock pvgn in the contract
    await pvgnToken.connect(owner).mint(poolContract.address, ethers.utils.parseUnits("62000000", 18));
    await usdtToken.connect(user).mint(user.address, ethers.utils.parseUnits("85000", 18));

    
  });

  it("should deploy successfully", async function () {
    expect(poolContract.address).to.not.be.undefined;
  });
  // Test case for rookie user
  it("should allow rookie user to invest and claim rewards", async function () {
    // Write test logic here
    let investmentAmount = ethers.utils.parseUnits("10000", 18)
    console.log("a1",user.address);
    console.log("b1", poolContract.address);
    await usdtToken.connect(user).approve(poolContract.address, investmentAmount);
    await poolContract.connect(user).invest(GardenTier.Rookie, investmentAmount, "0x0000000000000000000000000000000000000000");
    let contractBalance = await usdtToken.balanceOf(poolContract.address);
    let userBalance = await pvgnToken.balanceOf(user.address);
    console.log(userBalance);
    console.log(contractBalance);
    expect(userBalance.toString()).to.equal("42000000000000000000000");
    expect(contractBalance.toString()).to.equal("10000000000000000000000");
    // Increase the timestamp by 1 day (86400 seconds)
    await network.provider.send("evm_increaseTime", [86400*2]);
    // Mine a new block to persist the timestamp change
    await network.provider.send("evm_mine");
    await poolContract.connect(user).claimStake(GardenTier.Rookie);


  });

  // Test case for master user
  it("should allow master user to invest and claim rewards", async function () {
    // Write test logic here
  });

  // Test case for pro user
  it("should allow pro user to invest and claim rewards", async function () {
    // Write test logic here
  });

  // Test case for investment duration
  it("should prevent users from withdrawing investment before time is up", async function () {
    // Write test logic here
  });

  // Test case for reward distribution
  it("should distribute rewards correctly among all users in the pool", async function () {
    // Write test logic here
  });

  // Test case for pool balance
  it("should update pool balance correctly after each investment and withdrawal", async function () {
    // Write test logic here
  });
});
