const fs = require("fs");
const path = require("path");
const { MerkleTree } = require("merkletreejs");
const keccak256 = require("keccak256");

const generateMerkleRoot = (whitelistFile) => {
  const { addresses } = JSON.parse(
    fs.readFileSync(path.join(__dirname, "../whitelist", whitelistFile), {
      encoding: "utf8",
    })
  );

  const leaves = addresses.map((v) => keccak256(v));
  const tree = new MerkleTree(leaves, keccak256, { sort: true });
  const root = tree.getHexRoot();
  return root;
};

module.exports = { generateMerkleRoot };
