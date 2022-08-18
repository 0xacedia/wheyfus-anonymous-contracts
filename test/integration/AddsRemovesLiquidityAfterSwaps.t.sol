// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";

import "../Fixture.t.sol";

contract AddsRemovesLiquidityAfterSwaps is Fixture, ERC721TokenReceiver {
    using stdStorage for StdStorage;

    receive() external payable {}

    function setUp() public {}

    function testItAddsRemovesCorrectLiquidityAfterSwaps() public {
        // arrange
        w.whitelistMinter(babe, 500);
        deal(babe, 10 ether);

        // act
        uint256 tokenAmount = 1 ether;
        uint256 nftAmount = 100;
        w.mint(nftAmount);
        uint256[] memory tokenIds = new uint256[](nftAmount);
        for (uint256 i = 0; i < nftAmount; i++) {
            tokenIds[i] = i + 1;
        }
        w.addLiquidity{value: tokenAmount}(tokenIds, 0, type(uint256).max);
        buy(10);

        vm.startPrank(babe);
        uint256 babeTokenAmount = 1 ether;
        uint256 babeNftAmount = 15;
        w.mint(babeNftAmount);
        uint256[] memory babeTokenIds = new uint256[](babeNftAmount);
        for (uint256 i = 0; i < babeNftAmount; i++) {
            babeTokenIds[i] = nftAmount + i + 1;
        }
        w.addLiquidity{value: babeTokenAmount}(
            babeTokenIds,
            0,
            type(uint256).max
        );
        buy(5);
        vm.stopPrank();

        uint256 nftBalance = w.balanceOf(address(pair));
        uint256 tokenBalance = address(w).balance;

        assertEq(
            w.balanceOf(address(this)),
            20,
            "Should have transferred bought nfts"
        );
        assertEq(
            pair.spotPrice(),
            tokenBalance,
            "Spot price should match token reserves"
        );
        assertEq(pair.delta(), nftBalance, "Delta should match nft reserves");
    }

    function buy(uint256 numItemsToBuy) internal {
        (, , , uint256 inputValue, ) = pair.getBuyNFTQuote(numItemsToBuy);

        uint256 inputAmount = pair.swapTokenForAnyNFTs{value: inputValue}(
            numItemsToBuy,
            inputValue,
            address(this),
            false,
            address(0)
        );
    }
}
