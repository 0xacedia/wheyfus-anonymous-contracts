// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";

import "../Fixture.t.sol";

contract RemoveLiquidityTest is Fixture, ERC721TokenReceiver {
    event RemoveLiquidity(
        uint256 tokenAmount,
        uint256 nftAmount,
        uint256 shares
    );

    using stdStorage for StdStorage;

    uint256 public deposit;
    uint256 public shares;
    uint256[] public tokenIds;
    uint256 public mintAmount;

    receive() external payable {}

    function setUp() public {
        mintAmount = 6;
        w.mint(mintAmount);

        for (uint256 i = 0; i < mintAmount; i++) {
            tokenIds.push(i + 1);
        }

        deposit = 1 ether;
        shares = w.addLiquidity{value: deposit}(tokenIds, 0, 0);
    }

    function testItRemovesETHFromSudo() public {
        // arrange
        uint256 sudoBeforeBalance = address(w.pair()).balance;
        uint256 thisBeforeBalance = address(this).balance;

        // act
        w.removeLiquidity(tokenIds, 0, type(uint256).max);

        // assert
        assertEq(
            sudoBeforeBalance - address(w.pair()).balance,
            deposit,
            "Should have withdrawn ETH from sudo"
        );
        assertEq(
            address(this).balance - thisBeforeBalance,
            deposit,
            "Should have sent ETH to withdrawer"
        );
    }

    function testItEmitsRemoveLiquidityEvent() public {
        // arrange
        uint256 deposit = 1 ether;

        // act
        vm.expectEmit(true, true, true, true);
        emit RemoveLiquidity(
            deposit,
            tokenIds.length,
            deposit * tokenIds.length
        );
        w.removeLiquidity(tokenIds, 0, type(uint256).max);
    }

    function testItRemovesNftsFromSudo() public {
        // act
        w.removeLiquidity(tokenIds, 0, type(uint256).max);

        // assert
        for (uint256 i = 0; i < mintAmount; i++) {
            assertEq(
                w.ownerOf(tokenIds[i]),
                address(this),
                "Should have withdrawn NFT"
            );
        }
    }

    function testItUpdatesReserves() public {
        // act
        uint256 tokenAmountBefore = tokenIds.length;
        uint256 tokenAmountToRemove = tokenIds.length / 2; // remove 50% of liquidity
        for (uint256 i = 0; i < tokenAmountToRemove; i++) {
            tokenIds.pop();
        }
        w.removeLiquidity(tokenIds, 0, type(uint256).max);

        // assert
        assertEq(
            pair.spotPrice(),
            (deposit * tokenAmountToRemove) / tokenAmountBefore,
            "Should have updated ETH reserves"
        );
        assertEq(
            pair.delta(),
            tokenIds.length,
            "Should have updated nft reserves"
        );
    }

    function testItBurnsInitialDepositLPTokens() public {
        // arrange
        uint256 balanceBefore = lp.balanceOf(address(this));
        uint256 tokenAmountBefore = tokenIds.length;
        uint256 tokenAmountToRemove = tokenIds.length / 2; // remove 50% of liquidity
        for (uint256 i = 0; i < tokenAmountToRemove; i++) {
            tokenIds.pop();
        }

        // act
        w.removeLiquidity(tokenIds, 0, type(uint256).max);

        // assert
        assertEq(
            balanceBefore - lp.balanceOf(address(this)),
            (balanceBefore * tokenAmountToRemove) / tokenAmountBefore,
            "Should have burned LP shares"
        );
    }

    function testItCannotBurnIfSlippageIsTooHigh() public {
        // act
        vm.expectRevert("Price slippage");
        w.removeLiquidity(
            tokenIds,
            deposit / tokenIds.length,
            deposit / tokenIds.length - 1
        );

        vm.expectRevert("Price slippage");
        w.removeLiquidity(
            tokenIds,
            deposit / tokenIds.length + 1,
            deposit / tokenIds.length
        );
    }

    function testItRemovesCorrectAmountOfLiquidity() public {
        // arrange
        uint256 multiplier = 6;
        mintAmount *= multiplier;
        w.whitelistMinter(babe, mintAmount);

        vm.startPrank(babe);

        delete tokenIds;
        uint256 totalSupplyBefore = w.totalSupply();
        w.mint(mintAmount);

        for (
            uint256 i = totalSupplyBefore;
            i < totalSupplyBefore + mintAmount;
            i++
        ) {
            tokenIds.push(i + 1);
        }

        deposit *= multiplier;
        deal(babe, deposit);
        w.addLiquidity{value: deposit}(tokenIds, 0, type(uint256).max);
        uint256 totalLPSupplyBefore = lp.totalSupply();
        uint256 pairTokenBalanceBefore = w.balanceOf(address(pair));

        // act
        w.removeLiquidity(tokenIds, 0, type(uint256).max);
        vm.stopPrank();

        // assert
        assertEq(babe.balance, deposit, "Should have withdrawn ETH");
        assertEq(
            w.balanceOf(babe),
            tokenIds.length,
            "Should have withdrawn NFTs"
        );
        for (uint256 i = 0; i < tokenIds.length; i++) {
            assertEq(w.ownerOf(tokenIds[i]), babe, "Should have withdrawn NFT");
        }
        assertEq(
            lp.totalSupply(),
            totalLPSupplyBefore -
                ((totalLPSupplyBefore * tokenIds.length) /
                    pairTokenBalanceBefore)
        );
    }
}
