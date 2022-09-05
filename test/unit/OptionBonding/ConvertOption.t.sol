// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {PuttyV2} from "putty-v2/PuttyV2.sol";
import "../../Fixture.t.sol";

contract ConvertOptionTest is Fixture {
    using stdStorage for StdStorage;

    uint256[] public tokenIds;

    function setUp() public {}

    function testItBurnsCallOptionTokens() public {
        // arrange
        deal(address(co), address(this), 10e18, true);

        // act
        w.convertToOption(9, 1);

        // assert
        assertEq(co.balanceOf(address(this)), 1e18, "Should have burned call options");
    }

    function testItTransfersCallOption() public {
        // arrange
        deal(address(co), address(this), 10e18, true);

        // act
        (uint256 longPosition, PuttyV2.Order memory shortOrder) = w.convertToOption(10, 1);

        // assert
        assertEq(p.ownerOf(longPosition), address(this), "Should have sent long option to convertor");
        assertEq(
            p.ownerOf(uint256(p.hashOrder(shortOrder))), address(w), "Should have sent short option to wheyfu contract"
        );
    }

    function testItSetsCorrectOptionParameters() public {
        // arrange
        deal(address(co), address(this), 10e18, true);

        // act
        uint256 nonce = 35;
        (, PuttyV2.Order memory shortOrder) = w.convertToOption(10, nonce);

        // assert
        assertEq(shortOrder.maker, address(w), "Maker should be wheyfu contract");
        assertEq(shortOrder.isCall, true, "Should be call option");
        assertEq(shortOrder.isLong, false, "Should be short order");
        assertEq(shortOrder.baseAsset, address(weth), "Base asset should be weth");
        assertEq(shortOrder.strike, 0.1 ether * 10, "Strike should be 1 ether");
        assertEq(shortOrder.premium, 0, "Premium should be 0");
        assertEq(
            shortOrder.duration,
            w.optionExpiration() - block.timestamp,
            "Should have set duration to last until the final expiration"
        );
        assertEq(shortOrder.nonce, nonce, "Should have set nonce");
        assertEq(shortOrder.erc721Assets.length, 1, "Should have set 1 asset");
        assertEq(shortOrder.erc721Assets[0].token, address(w), "Should have set token to be wheyfu");
        assertEq(
            type(uint256).max - shortOrder.erc721Assets[0].tokenId, 10, "Should have set tokenId to max - num assets"
        );
    }

    function testItCannotCreateOptionForMoreThan20Assets() public {
        // act
        vm.expectRevert("Must convert 50 or less assets");
        w.convertToOption(51, 1);
    }

    function testItCannotCreateOptionForLessThan1Asset() public {
        // act
        vm.expectRevert("Must convert at least one asset");
        w.convertToOption(0, 1);
    }

    function testIsValidSignatureReturnsFalse() public {
        // arrange
        bytes memory empty;

        // act
        bytes4 v = w.isValidSignature(bytes32(0), empty);

        // assert
        assertEq(v, bytes4(0), "Should have returned invalid signature");
    }
}
