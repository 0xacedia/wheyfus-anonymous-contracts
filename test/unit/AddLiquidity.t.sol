// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../Fixture.t.sol";

contract AddLiquidityTest is Fixture {
    event AddLiquidity(uint256 tokenAmount, uint256 nftAmount, uint256 shares);

    using stdStorage for StdStorage;

    uint256[] public tokenIds;
    uint256 public mintAmount;

    function setUp() public {
        mintAmount = 10;
        w.mint(mintAmount);

        for (uint256 i = 0; i < mintAmount; i++) {
            tokenIds.push(i + 1);
        }
    }

    function testItSendsETHToSudo() public {
        // arrange
        uint256 deposit = 1 ether;

        // act
        w.addLiquidity{value: deposit}(tokenIds, 0, 0);

        // assert
        assertEq(
            address(pair).balance,
            deposit,
            "Should have transferred ETH to sudo"
        );
    }

    function testItEmitsAddLiquidityEvent() public {
        // arrange
        uint256 deposit = 1 ether;

        // act
        vm.expectEmit(true, true, true, true);
        emit AddLiquidity(1 ether, tokenIds.length, 1 ether * tokenIds.length);
        w.addLiquidity{value: deposit}(tokenIds, 0, 0);
    }

    function testItSendsNftsToSudo() public {
        // act
        w.addLiquidity{value: 1 ether}(tokenIds, 0, 0);

        // assert
        for (uint256 i = 0; i < mintAmount; i++) {
            assertEq(w.ownerOf(tokenIds[i]), address(pair));
        }
    }

    function testItUpdatesReserves() public {
        // arrange
        uint256 deposit = 1 ether;

        // act
        w.addLiquidity{value: deposit}(tokenIds, 0, 0);

        // assert
        assertEq(pair.spotPrice(), deposit, "Should have updated ETH reserves");
        assertEq(
            pair.delta(),
            tokenIds.length,
            "Should have updated nft reserves"
        );
    }

    function testItMintsInitialDepositLPTokens() public {
        // arrange
        uint256 deposit = 1 ether;

        // act
        w.addLiquidity{value: deposit}(tokenIds, 0, 0);

        // assert
        assertEq(
            lp.balanceOf(address(this)),
            deposit * tokenIds.length,
            "Should have minted initial LP shares"
        );
    }

    function testItCannotMintIfSlippageIsTooHigh() public {
        // arrange
        uint256 deposit = 1 ether;
        w.addLiquidity{value: deposit}(tokenIds, 0, 0);

        // act
        vm.expectRevert("Price slippage");
        w.addLiquidity{value: 1 ether}(
            tokenIds,
            0,
            deposit / tokenIds.length - 1
        );

        vm.expectRevert("Price slippage");
        w.addLiquidity{value: 1 ether}(
            tokenIds,
            deposit / tokenIds.length + 1,
            deposit / tokenIds.length
        );
    }

    function testItMintsCorrectAmountOfLPTokens() public {
        // arrange
        uint256 deposit = 1 ether;
        w.addLiquidity{value: deposit}(tokenIds, 0, 0);

        uint256 totalSupplyBefore = w.totalSupply();
        uint256 multiplier = 2;
        mintAmount *= 3;
        w.whitelistMinter(babe, mintAmount);
        vm.startPrank(babe);

        delete tokenIds;
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

        // act
        w.addLiquidity{value: deposit}(tokenIds, 0, type(uint256).max);
        vm.stopPrank();

        // assert
        assertEq(
            lp.balanceOf(babe) / lp.balanceOf(address(this)),
            multiplier,
            "Should have minted LP shares"
        );
    }
}
