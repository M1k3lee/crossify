const TokenFactory = artifacts.require("TokenFactory");
const CrossifyBridge = artifacts.require("CrossifyBridge");
const MockWormholeBridge = artifacts.require("MockWormholeBridge");
const CrossifyTest = artifacts.require("CrossifyTest");

module.exports = async function(deployer, network, accounts) {
  // Deploy MockWormholeBridge for testing
  await deployer.deploy(MockWormholeBridge);
  const mockWormholeBridge = await MockWormholeBridge.deployed();
  console.log("MockWormholeBridge deployed at:", mockWormholeBridge.address);
  
  // Deploy TokenFactory with MockWormholeBridge address
  await deployer.deploy(TokenFactory, mockWormholeBridge.address);
  const tokenFactory = await TokenFactory.deployed();
  console.log("TokenFactory deployed at:", tokenFactory.address);
  
  // Deploy CrossifyBridge with TokenFactory and MockWormholeBridge addresses
  await deployer.deploy(
    CrossifyBridge, 
    tokenFactory.address, 
    mockWormholeBridge.address, 
    mockWormholeBridge.address // Using same mock for token bridge
  );
  const crossifyBridge = await CrossifyBridge.deployed();
  console.log("CrossifyBridge deployed at:", crossifyBridge.address);
  
  // Deploy CrossifyTest for testnet testing
  await deployer.deploy(
    CrossifyTest,
    tokenFactory.address,
    crossifyBridge.address,
    mockWormholeBridge.address
  );
  const crossifyTest = await CrossifyTest.deployed();
  console.log("CrossifyTest deployed at:", crossifyTest.address);
  
  console.log("Deployment complete!");
};
