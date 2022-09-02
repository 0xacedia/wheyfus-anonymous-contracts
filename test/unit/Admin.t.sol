// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../Fixture.t.sol";

contract AdminTest is Fixture {
    function setUp() public {}

    function testItSetsPair() public {
        // act
        w.setPair(payable(address(0xdead)));

        // assert
        assertEq(address(w.pair()), address(0xdead), "Should have set pair");
    }

    function testItCannotSetPairIfNotAdmin() public {
        // act
        vm.prank(babe);
        vm.expectRevert("UNAUTHORIZED");
        w.setPair(payable(address(0xdead)));
    }

    function testItClosesWhitelist() public {
        // act
        w.closeWhitelist();

        // assert
        assertEq(w.closedWhitelist(), true, "Should have set whitelist as closed");
    }

    function testItCannotCloseWhitelistIfNotAdmin() public {
        // act
        vm.prank(babe);
        vm.expectRevert("UNAUTHORIZED");
        w.closeWhitelist();
    }

    function testItCannotWhitelistMinterIfNotAdmin() public {
        // act
        vm.prank(babe);
        vm.expectRevert("UNAUTHORIZED");
        w.whitelistMinter(babe, 1);
    }
}
