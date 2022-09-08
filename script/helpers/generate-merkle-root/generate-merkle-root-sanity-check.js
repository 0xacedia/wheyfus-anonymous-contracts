const { generateMerkleRoot } = require("./generate-merkle-root");

const main = () => {
  const whitelistFile = "discord-whitelist.json";
  const merkleRoots = generateMerkleRoot(whitelistFile);

  console.log("Merkle root: ", merkleRoots);
};

main();
