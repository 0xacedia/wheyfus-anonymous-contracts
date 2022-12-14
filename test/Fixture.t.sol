// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "lssvm/LSSVMPairFactory.sol";
import "lssvm/LSSVMPair.sol";
import "lssvm/LSSVMPairEnumerableETH.sol";
import "lssvm/LSSVMPairMissingEnumerableETH.sol";
import "lssvm/LSSVMPairEnumerableERC20.sol";
import "lssvm/LSSVMPairMissingEnumerableERC20.sol";
import "lssvm/bonding-curves/ICurve.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {PuttyV2} from "putty-v2/PuttyV2.sol";

import {MockERC721} from "./mocks/MockERC721.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockWeth} from "./mocks/MockWeth.sol";

import "../src/Wheyfu.sol";
import "../src/lib/MintBurnToken.sol";
import "../src/OptionBonding.sol";
import "../src/lib/BondingNft.sol";
import "../src/TokenUri.sol";

contract Fixture is Test {
    MockERC721 public bayc;
    MintBurnToken public co;
    MockWeth public weth;

    Wheyfu public w;
    TokenUri public t;

    MintBurnToken public lp;
    BondingNft public b;
    BondingNft public feeB;
    PuttyV2 public p;

    LSSVMPairFactory public sudoPairFactory;
    ICurve public xykCurve;
    LSSVMPair public pair;

    // 1%
    uint96 public fee = 1e18 / 100;

    // 0.5%
    uint256 public protocolFee = 1e18 / 200;

    address payable public babe;

    constructor() {
        babe = payable(address(0xbabe));

        // setup sudoswap
        setupSudoswap();

        // deploy contracts
        co = new MintBurnToken("Call option token", "CALLO", 18);
        lp = new MintBurnToken("LP token", "LP", 18);
        weth = new MockWeth();
        p = new PuttyV2("https://base", 0, address(weth));
        w = new Wheyfu(address(lp), address(co), address(p), address(weth));
        t = new TokenUri(payable(address(w)));
        b = w.optionBondingNft();
        feeB = w.feeBondingNft();

        uint256[] memory empty = new uint256[](0);
        pair = sudoPairFactory.createPairETH(
            IERC721(address(w)), xykCurve, payable(0), LSSVMPair.PoolType.TRADE, 0, fee, 0, empty
        );
        vm.label(address(pair), "Pair");

        w.setPair(payable(address(pair)));
        w.setTokenUri(address(t));
        pair.transferOwnership(address(w));

        bayc = new MockERC721("Mock bored apes", "BAYC");

        // transfer ownership to Wheyfu
        lp.setMinterBurner(address(w), true);
        lp.setOwner(address(w));

        // transfer ownership to co
        co.setMinterBurner(address(w), true);
        co.setOwner(address(w));

        // set whitelist
        w.whitelistMinter(address(this), 500);
        w.whitelistMinter(address(p), 500);
    }

    function setupSudoswap() public {
        LSSVMPairMissingEnumerableETH pairMissingEnumerableETHTemplate = new LSSVMPairMissingEnumerableETH();
        LSSVMPairEnumerableETH pairEnumerableETHTemplate = new LSSVMPairEnumerableETH();

        sudoPairFactory = new LSSVMPairFactory(
            LSSVMPairEnumerableETH(payable(address(pairMissingEnumerableETHTemplate))),
            pairMissingEnumerableETHTemplate,
            LSSVMPairEnumerableERC20(payable(0)),
            LSSVMPairMissingEnumerableERC20(payable(0)),
            payable(0),
            protocolFee
        );

        xykCurve = ICurve(deployCode("XykCurve.json"));
        sudoPairFactory.setBondingCurveAllowed(ICurve(xykCurve), true);
    }
}
