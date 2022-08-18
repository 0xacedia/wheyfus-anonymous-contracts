// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";

import "../Fixture.t.sol";

contract AddsRemovesLiquidityAfterSwaps is Fixture, ERC721TokenReceiver {
    using stdStorage for StdStorage;

    uint256[] public tokenIds;

    receive() external payable {}

    function setUp() public {}

    function testItAddsRemovesCorrectLiquidityAfterSwaps() public {
        // arange
        uint256 depositAmount = 100;
        w.mint(depositAmount);

        for (uint256 i = 0; i < depositAmount; i++) {
            tokenIds.push(i + 1);
        }

        w.addLiquidity{value: 1 ether}(tokenIds, 0, type(uint256).max);
        buy(10);

        uint256 tokenAmount = address(pair).balance / 10;
        uint256 nftAmount = w.balanceOf(address(pair)) / 10;

        w.mint(nftAmount);
        delete tokenIds;
        for (uint256 i = depositAmount; i < nftAmount; i++) {
            tokenIds.push(i + 1);
        }

        w.addLiquidity{value: tokenAmount}(tokenIds, 0, type(uint256).max);
        buy(10);
    }

    function buy(uint256 inputAmount) internal {
        uint256 numItemsToBuy = 3;
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
