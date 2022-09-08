const { defaultAbiCoder } = require("@ethersproject/abi");
const { generateMerkleRoot } = require("./generate-merkle-root");

const main = async () => {
  const whitelistFile = process.argv[2];

  const merkleRoot = generateMerkleRoot(whitelistFile);

  process.stdout.write(merkleRoot);
  process.exit();
};

main();
