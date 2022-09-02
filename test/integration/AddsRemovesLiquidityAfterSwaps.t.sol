// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
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
        uint256 buyAmount = 10;
        buy(buyAmount);

        vm.startPrank(babe);
        uint256 babeTokenAmount = 1 ether;
        uint256 babeNftAmount = 15;
        w.mint(babeNftAmount);
        uint256[] memory babeTokenIds = new uint256[](babeNftAmount);
        for (uint256 i = 0; i < babeNftAmount; i++) {
            babeTokenIds[i] = nftAmount + i + 1;
        }
        w.addLiquidity{value: babeTokenAmount}(babeTokenIds, 0, type(uint256).max);
        uint256 babeBuyAmount = 5;
        buy(babeBuyAmount);
        vm.stopPrank();

        w.whitelistMinter(address(this), 3000);
        for (uint256 i = 0; i < 10; i++) {
            i % 3 == 0 ? sell(i + 1) : buy(Math.min(i + 1, w.balanceOf(address(pair))));
        }

        w.skim();

        uint256 nftBalance = w.balanceOf(address(pair));
        uint256 tokenBalance = address(pair).balance;

        assertEq(pair.spotPrice(), tokenBalance, "Spot price should match token reserves");
        assertEq(pair.delta(), nftBalance, "Delta should match nft reserves");
    }

    function buy(uint256 numItemsToBuy) internal {
        (,,, uint256 inputValue, uint256 protocolFee) = pair.getBuyNFTQuote(numItemsToBuy);

        uint256 inputAmount =
            pair.swapTokenForAnyNFTs{value: inputValue}(numItemsToBuy, inputValue, address(this), false, address(0));
    }

    function sell(uint256 numItemsToSell) internal {
        uint256[] memory nftIds = new uint256[](numItemsToSell);
        uint256 totalSupply = w.mint(numItemsToSell);
        w.setApprovalForAll(address(pair), true);
        for (uint256 i = 0; i < numItemsToSell; i++) {
            nftIds[i] = (totalSupply - numItemsToSell) + i;
        }

        (,,, uint256 outputAmount, uint256 protocolFee) = pair.getSellNFTQuote(numItemsToSell);
        uint256 inputAmount = pair.swapNFTsForToken(nftIds, outputAmount, payable(address(this)), false, address(0));
    }
}
