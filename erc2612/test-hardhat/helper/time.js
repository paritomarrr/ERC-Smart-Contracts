const { time } = require('@nomicfoundation/hardhat-network-helpers');
const { ethers } = require('hardhat');

const clock = {
    blocknumber: () => time.latestBlock().then(ethers.toBigInt),
    timestamp: () => time.latest().then(ethers.toBigInt),
  };

  module.exports = {
    clock
  }