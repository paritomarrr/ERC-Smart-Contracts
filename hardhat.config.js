require("@nomicfoundation/hardhat-toolbox");
const fs = require("fs");
const path = require("path");

for (const f of fs.readdirSync(path.join(__dirname, "hardhat"))) {
  require(path.join(__dirname, "hardhat", f));
}


/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.28",
};
