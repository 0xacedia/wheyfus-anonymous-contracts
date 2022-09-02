// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {PuttyV2} from "putty-v2/PuttyV2.sol";
import "../Fixture.t.sol";

contract WheyfuInitTest is Fixture {
    function setUp() public {}

    function testItSetsMaxSupply() public {
        assertEq(w.MAX_SUPPLY(), 15_000, "Should have set max supply");
    }

    function testItSetsWhitelistAsOpen() public {
        assertEq(w.closedWhitelist(), false, "Should have set whitelist as open");
    }

    function testItSetsWhitelistedSupplyTo0() public {
        assertEq(w.whitelistedSupply(), 1000, "Should have set whitelisted supply to be 1000");
    }

    function testItSetsTotalSupplyTo200() public {
        assertEq(w.totalSupply(), 0, "Should have set total supply to be 0");
    }

    function testItSetsSudoPair() public {
        assertEq(address(w.pair()), address(pair), "Should have set sudo pair");
    }

    function testItSetsNameAndSymbol() public {
        assertEq(w.name(), "Wheyfus anonymous :3", "Should have set name");
        assertEq(w.symbol(), "UwU", "Should have set symbol");
    }
}
