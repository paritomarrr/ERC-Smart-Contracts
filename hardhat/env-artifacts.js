// hardhat/env-artifacts.js
const { HardhatError } = require("hardhat/internal/core/errors");

function isExpectedError(e, suffix) {
  return HardhatError.isHardhatError(e) && e.number === 700 && suffix !== "";
}

extendEnvironment((hre) => {
  const suffixes = ["Mock", "Upgradeable", ""];

  const originalReadArtifact = hre.artifacts.readArtifact;

  hre.artifacts.readArtifact = async function (name) {
    for (const suffix of suffixes) {
      try {
        return await originalReadArtifact.call(this, name + suffix);
      } catch (e) {
        if (isExpectedError(e, suffix)) continue;
        else throw e;
      }
    }
    throw new Error(`Artifact not found for: ${name}`);
  };
});
