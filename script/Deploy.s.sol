// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {LSSVMPairFactory} from "lssvm/LSSVMPairFactory.sol";
import {LSSVMPair} from "lssvm/LSSVMPair.sol";
import {ICurve} from "lssvm/bonding-curves/ICurve.sol";

import {Wheyfu} from "../src/Wheyfu.sol";
import {TokenUri} from "../src/TokenUri.sol";
import {MintBurnToken} from "../src/MintBurnToken.sol";

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
        console.log("bonding nft:");
        console.log(address(wheyfu.bondingNft()));
        TokenUri tokenUri = new TokenUri(payable(address(wheyfu)));

        // create the wheyfu:eth sudoswap pair
        LSSVMPairFactory sudoFactory = LSSVMPairFactory(
            payable(vm.envAddress("SUDO_FACTORY_ADDRESS"))
        );
        ICurve xykCurve = ICurve(vm.envAddress("SUDO_XYK_CURVE_ADDRESS"));
        uint256[] memory empty = new uint256[](0);
        LSSVMPair pair = sudoFactory.createPairETH(
            IERC721(address(wheyfu)),
            xykCurve,
            payable(0),
            LSSVMPair.PoolType.TRADE,
            0,
            0,
            0,
            empty
        );
        console.log("pair:");
        console.log(address(pair));

        // set the pair and tokenUri contracts
        wheyfu.setPair(payable(address(pair)));
        wheyfu.setTokenUri(address(tokenUri));
        pair.transferOwnership(address(wheyfu));

        // authorize wheyfu to mint/burn lp tokens then give up control
        lp.setMinterBurner(address(wheyfu), true);
        lp.setOwner(address(0));

        // authorize wheyfu to mint/burn call option tokens then give up control
        co.setMinterBurner(address(wheyfu), true);
        co.setOwner(address(0));

        // authorize the putty contract to mint 1000 wheyfu NFTs
        // this can be increased in the future to 9000 but set it
        // to be low as a safety measure for now.
        wheyfu.whitelistMinter(address(putty), 1000);

        // seed the pair with some liquidity
        wheyfu.whitelistMinter(msg.sender, 50);
        wheyfu.mint(5);

        uint256[] memory tokenIds = new uint256[](5);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        tokenIds[2] = 3;
        tokenIds[3] = 4;
        tokenIds[4] = 5;
        wheyfu.addLiquidity{value: 0.03 ether}(tokenIds, 0, type(uint256).max);
    }
}
