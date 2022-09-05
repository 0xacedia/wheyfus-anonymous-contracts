// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../Fixture.t.sol";

contract AdminTest is Fixture {
    function setUp() public {}

    function testItCannotSetPairIfAlreadySet() public {
        // act
        vm.expectRevert("Pair already set");
        w.setPair(payable(address(0xdead)));
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

    function testItSetsTokenUri() public {
        // act
        w.setTokenUri(babe);

        // assert
        assertEq(address(w.tokenUri()), babe, "Should have set token uri");
    }

    function testItCannotSetTokenUriIfNotAdmin() public {
        // act
        vm.prank(babe);
        vm.expectRevert("UNAUTHORIZED");
        w.setTokenUri(babe);
    }
}
