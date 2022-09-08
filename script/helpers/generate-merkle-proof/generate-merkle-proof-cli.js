const { defaultAbiCoder } = require("@ethersproject/abi");
const { generateMerkleProof } = require("./generate-merkle-proof");

const main = async () => {
  const whitelistFile = process.argv[2];
  const target = process.argv[3];

  const merkleProof = generateMerkleProof(target, whitelistFile);

  process.stdout.write(defaultAbiCoder.encode(["bytes32[]"], [merkleProof]));
  process.exit();
};

main();
