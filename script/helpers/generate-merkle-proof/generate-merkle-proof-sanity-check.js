const { generateMerkleProof } = require("./generate-merkle-proof");

const main = () => {
  const rankingFile = "discord-whitelist.json";
  const target = "0x5B263F93f01B2F7C8AD11D001EA282EBB534fef1";
  const merkleProof = generateMerkleProof(target, rankingFile);

  console.log("Merkle proof: ", merkleProof);
};

main();
