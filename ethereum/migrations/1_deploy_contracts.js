const TokenFactory = artifacts.require("TokenFactory");
const CrossifyBridge = artifacts.require("CrossifyBridge");

module.exports = async function(deployer, network) {
  // Deploy TokenFactory
  await deployer.deploy(TokenFactory);
  const tokenFactory = await TokenFactory.deployed();
  
  // Deploy CrossifyBridge with TokenFactory address
  await deployer.deploy(CrossifyBridge, tokenFactory.address);
};
