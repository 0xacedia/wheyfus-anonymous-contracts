// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {LSSVMPairFactory} from "lssvm/LSSVMPairFactory.sol";
import {LSSVMPair} from "lssvm/LSSVMPair.sol";
import {ICurve} from "lssvm/bonding-curves/ICurve.sol";

import {Wheyfu} from "../src/Wheyfu.sol";
import {TokenUri} from "../src/TokenUri.sol";
import {MintBurnToken} from "../src/lib/MintBurnToken.sol";
import {Mint} from "../src/Mint.sol";

contract DeployScript is Script {
    function run() public {
        vm.startBroadcast();

        // create the call option and lp tokens
        MintBurnToken co = new MintBurnToken(
            "Wheyfu call option token",
            "WCALLO",
            18
        );
        console.log("call option token:");
        console.log(address(co));
        MintBurnToken lp = new MintBurnToken("Wheyfu LP token", "WLP", 18);
        console.log("lp token:");
        console.log(address(lp));

        // create the wheyfu contract
        address putty = vm.envAddress("PUTTY_ADDRESS");
        address weth = vm.envAddress("WETH_ADDRESS");
        Wheyfu wheyfu = new Wheyfu(address(lp), address(co), putty, weth);
        console.log("wheyfu:");
        console.log(address(wheyfu));
        console.log("option bonding nft:");
        console.log(address(wheyfu.optionBondingNft()));
        console.log("fee bonding nft:");
        console.log(address(wheyfu.feeBondingNft()));
        TokenUri tokenUri = new TokenUri(payable(address(wheyfu)));

        Mint mint = new Mint(payable(address(wheyfu)));
        console.log("mint:");
        console.log(address(mint));

        // create the wheyfu:eth sudoswap pair
        LSSVMPairFactory sudoFactory = LSSVMPairFactory(payable(vm.envAddress("SUDO_FACTORY_ADDRESS")));
        ICurve xykCurve = ICurve(vm.envAddress("SUDO_XYK_CURVE_ADDRESS"));
        uint256[] memory empty = new uint256[](0);
        LSSVMPair pair = sudoFactory.createPairETH(
            IERC721(address(wheyfu)), xykCurve, payable(0), LSSVMPair.PoolType.TRADE, 0, 0, 0, empty
        );
        console.log("pair:");
        console.log(address(pair));

        // set the pair and tokenUri contracts
        wheyfu.setPair(payable(address(pair)));
        wheyfu.setTokenUri(address(tokenUri));
        pair.transferOwnership(address(wheyfu));

        // authorize wheyfu to mint/burn lp tokens then give up control
        lp.setMinterBurner(address(wheyfu), true);
        lp.setOwner(address(wheyfu));

        // authorize wheyfu to mint/burn call option tokens then give up control
        co.setMinterBurner(address(wheyfu), true);

        // TODO: JUST FOR TESTING (REMOVE THIS AT LAUNCH) ______
        co.setMinterBurner(msg.sender, true);
        co.mint(msg.sender, 500 * 1e18);
        // TODO: JUST FOR TESTING (REMOVE THIS AT LAUNCH) ^^^^^

        co.setOwner(address(wheyfu));

        // authorize the putty contract to mint 18k wheyfu nfts
        wheyfu.whitelistMinter(address(putty), 18_000);

        // seed the pair with some liquidity
        wheyfu.whitelistMinter(msg.sender, 50);
        wheyfu.mint(20);

        uint256[] memory tokenIds = new uint256[](5);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        tokenIds[2] = 3;
        tokenIds[3] = 4;
        tokenIds[4] = 5;
        wheyfu.addLiquidityAndOptionStake{value: 0.012 ether}(tokenIds, 0, type(uint256).max, 1);

        tokenIds = new uint256[](5);
        tokenIds[0] = 6;
        tokenIds[1] = 7;
        tokenIds[2] = 8;
        tokenIds[3] = 9;
        tokenIds[4] = 10;
        wheyfu.addLiquidityAndFeeStake{value: 0.012 ether}(tokenIds, 0, type(uint256).max, 1);

        // whitelist the mint contract for 9k wheyfus
        wheyfu.whitelistMinter(address(mint), 9000);
        mint.setMerkleRoot(generateMerkleRoot("discord-whitelist.json"));
        // bytes32[] memory proof = generateMerkleProof("discord-whitelist.json", msg.sender);
        // mint.mint(1, proof);

        vm.stopBroadcast();
    }

    function generateMerkleRoot(string memory whitelistFile) public returns (bytes32) {
        string[] memory inputs = new string[](3);

        inputs[0] = "node";
        inputs[1] = "./script/helpers/generate-merkle-root/generate-merkle-root-cli.js";
        inputs[2] = whitelistFile;

        bytes memory res = vm.ffi(inputs);
        bytes32 output = abi.decode(res, (bytes32));

        return output;
    }

    function generateMerkleProof(string memory whitelistFile, address target) public returns (bytes32[] memory) {
        string[] memory inputs = new string[](4);

        inputs[0] = "node";
        inputs[1] = "./script/helpers/generate-merkle-proof/generate-merkle-proof-cli.js";
        inputs[2] = whitelistFile;
        inputs[3] = Strings.toHexString(target);

        bytes memory res = vm.ffi(inputs);
        bytes32[] memory output = abi.decode(res, (bytes32[]));

        return output;
    }
}
