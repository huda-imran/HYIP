require("@nomicfoundation/hardhat-toolbox");
require('dotenv').config();
require("@nomiclabs/hardhat-ethers");

const { API_URL, PRIVATE_KEY } = process.env;


/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.18",
  defaultNetwork: "polygon_mumbai",
  networks: {
    hardhat: {},
    polygon_mumbai: {
    url: API_URL,
    accounts: [`0x${PRIVATE_KEY}`]
    }
  },
  etherscan: {
    apiKey: "NRK5SMUQGF2FZFX5NU1VSUMZEPQJM2F5NA",
  },
};