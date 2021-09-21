const gNFT = artifacts.require("gNFT");

module.exports = function (deployer) {
  deployer.deploy(gNFT);
};