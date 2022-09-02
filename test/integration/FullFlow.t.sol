// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import "../Fixture.t.sol";

contract FullFlowTest is Fixture, ERC721TokenReceiver {
    receive() external payable {}

    function setUp() public {}

    function testFlow() public {
        skip(10);
        uint256 amount = 5;
        w.whitelistMinter(babe, amount);

        // mint
        vm.startPrank(babe);
        w.mint(amount);

        // addLiquidity
        deal(babe, 1 ether);
        uint256[] memory tokenIds = new uint256[](amount);
        for (uint256 i = 0; i < amount; i++) {
            tokenIds[i] = i + 1;
        }
        uint256 shares = w.addLiquidity{value: 1 ether}(tokenIds, 0, type(uint256).max);

        // stake
        uint256 tokenId = w.stake(uint96(shares), 0);

        // unstake
        skip(10 days);
        uint256 callOptionAmount = w.unstake(tokenId);

        // convert to option
        (uint256 longTokenId, PuttyV2.Order memory shortOrder) = w.convertToOption(20, 1);

        PuttyV2.Order memory longOrder = abi.decode(abi.encode(shortOrder), (PuttyV2.Order));
        longOrder.isLong = true;

        // exercise option
        deal(address(weth), address(babe), w.STRIKE() * 20);
        weth.approve(address(p), type(uint256).max);
        uint256[] memory empty = new uint256[](0);
        p.exercise(longOrder, empty);

        // withdraw liquidity
        w.removeLiquidity(tokenIds, 0, type(uint256).max);
        vm.stopPrank();

        // withdraw eth
        PuttyV2.Order[] memory orders = new PuttyV2.Order[](1);
        orders[0] = shortOrder;
        w.withdrawWeth(orders, address(this));

        // assert
        assertEq(weth.balanceOf(address(this)), w.STRIKE() * 20, "Should have withdrawn strike eth to owner");

        assertEq(
            w.balanceOf(babe), 20 + amount, "Should have sent 20 wheyfu nfts to babe and withdrawn `amount` tokens"
        );

        assertEq(p.ownerOf(longTokenId), address(0xdead), "Should have sent long option to 0xdead");

        assertEq(callOptionAmount, 10 days * w.rewardRate(), "Should have sent 100% of emissions to babe");

        assertEq(co.balanceOf(babe), callOptionAmount - 20e18, "Should have burned 20 call option tokens from babe");

        assertEq(babe.balance, 1 ether, "Should have withdrawn eth liqudity");
    }
}
