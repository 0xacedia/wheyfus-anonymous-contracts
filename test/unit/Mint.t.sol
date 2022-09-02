// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../Fixture.t.sol";

contract MintTest is Fixture {
    using stdStorage for StdStorage;

    function setUp() public {}

    function testItIncrementsBalance() public {
        // act
        w.mint(10);

        // assert
        assertEq(w.balanceOf(address(this)), 10);
    }

    function testItDecrementsMintWhitelist() public {
        // arrange
        uint256 mintWhitelistAmountBefore = w.mintWhitelist(address(this));

        // act
        w.mint(10);

        // assert
        assertEq(
            w.mintWhitelist(address(this)), mintWhitelistAmountBefore - 10, "Should have decremented mint whitelist"
        );
    }

    function testItIncrementsTotalSupply() public {
        // act
        w.mint(2);

        // assert
        assertEq(w.totalSupply(), 2);
    }

    function testItMintsToCaller() public {
        // act
        w.mint(3);

        // assert
        assertEq(w.ownerOf(1), address(this));
        assertEq(w.ownerOf(2), address(this));
        assertEq(w.ownerOf(3), address(this));
    }

    function testItMintsToTarget() public {
        // act
        w.mintTo(3, babe);

        // assert
        assertEq(w.ownerOf(1), babe);
        assertEq(w.ownerOf(2), babe);
        assertEq(w.ownerOf(3), babe);
        assertEq(w.balanceOf(babe), 3);
    }

    function testItSetsWhitelist() public {
        // act
        w.whitelistMinter(babe, 10);

        // assert
        assertEq(w.mintWhitelist(babe), 10, "Should have set babe whitelist amount");
    }

    function testItIncrementsWhitelistedSupply() public {
        // arrange
        uint256 whitelistedSupplyBefore = w.whitelistedSupply();
        uint256 babeFinalAmount = 17;
        uint256 bobFinalAmount = 3;
        uint256 beefFinalAmount = 93;

        // act
        w.whitelistMinter(babe, 10);
        w.whitelistMinter(babe, 5);
        w.whitelistMinter(babe, babeFinalAmount);
        w.whitelistMinter(address(0xb0b), 3);
        w.whitelistMinter(address(0xb0b), bobFinalAmount);
        w.whitelistMinter(address(0xbeef), beefFinalAmount);

        // assert
        assertEq(
            w.whitelistedSupply(),
            whitelistedSupplyBefore + bobFinalAmount + babeFinalAmount + beefFinalAmount,
            "Should have set whitelisted supply"
        );
    }

    function testItCannotWhitelistMoreThanMaxSupply() public {
        // arrange
        uint256 maxSupply = w.MAX_SUPPLY();
        w.whitelistMinter(babe, w.MAX_SUPPLY() / 2);

        // act
        vm.expectRevert("Max supply already reached");
        w.whitelistMinter(address(0xb0b), maxSupply / 2);
    }

    function testItCannotWhitelistIfClosed() public {
        // arrange
        w.closeWhitelist();

        // act
        vm.expectRevert("Whitelist has been closed");
        w.whitelistMinter(address(0xb0b), 0);
    }
}
