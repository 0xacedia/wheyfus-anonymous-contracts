// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {PuttyV2} from "putty-v2/PuttyV2.sol";
import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import "../Fixture.t.sol";

contract WithdrawWethTest is Fixture, ERC721TokenReceiver {
    uint256[] public tokenIds;

    function setUp() public {}

    function testItTransfersWethToRecipient() public {
        // arrange
        deal(address(co), address(this), 10e18, true);
        (, PuttyV2.Order memory shortOrder) = w.convertToOption(10, 1);
        PuttyV2.Order[] memory orders = new PuttyV2.Order[](1);
        orders[0] = shortOrder;
        PuttyV2.Order memory longOrder = abi.decode(abi.encode(shortOrder), (PuttyV2.Order));
        longOrder.isLong = true;
        uint256[] memory empty = new uint256[](0);

        // act
        deal(address(weth), address(this), 10 * w.STRIKE());
        weth.approve(address(p), 10 * w.STRIKE());
        p.exercise(longOrder, empty);
        w.withdrawWeth(orders, address(babe));

        // assert
        assertEq(weth.balanceOf(babe), 10 * w.STRIKE(), "Should have transferred weth to babe");
    }

    function testItCannotCallIfNotOwner() public {
        // arrange
        PuttyV2.Order[] memory orders = new PuttyV2.Order[](1);

        // act
        vm.prank(babe);
        vm.expectRevert("UNAUTHORIZED");
        w.withdrawWeth(orders, address(babe));
    }
}
