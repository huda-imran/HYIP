const hre = require("hardhat");

async function main() {
  
  // const USDT = await hre.ethers.getContractFactory("MyToken");
  // const usdt = await USDT.deploy("usdtToken", "USDT");
  // await usdt.deployed();
  // const PVGN = await hre.ethers.getContractFactory("MyToken");
  // const pvgn = await PVGN.deploy("pvgnToken", "PVGN");
  // await pvgn.deployed();
  const HYIP = await hre.ethers.getContractFactory("HYIP");
  const hyip = await HYIP.deploy("0x8B7760e6cC84A4F7eE863370C3Ca0862c2c63EF7", "0x86d70eB1E9f06A8F67873d0f6020d378C35a389B");
  await hyip.deployed();

  //console.log("USDT address", usdt.address);
  //console.log("PVGN address", pvgn.address);
  console.log("HYIP address", hyip.address);



  
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
