const clock = {
    blocknumber: () => time.latestBlock().then(ethers.toBigInt),
    timestamp: () => time.latest().then(ethers.toBigInt),
  };

  module.exports = {
    clock
  }