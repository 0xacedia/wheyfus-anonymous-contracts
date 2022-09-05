// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../Fixture.t.sol";

contract SkimTest is Fixture {
    function setUp() public {
        uint256 tokenAmount = 0.56 ether;
        uint256 nftAmount = 3;

        w.mint(nftAmount);
        uint256[] memory tokenIds = new uint256[](nftAmount);
        for (uint256 i = 0; i < nftAmount; i++) {
            tokenIds[i] = i + 1;
        }

        w.addLiquidity{value: tokenAmount}(tokenIds, 0, type(uint256).max);
    }

    function testItWithdrawsEth() public {
        // arrange
        uint256 amount = 0.01 ether;
        payable(address(pair)).call{value: amount}("");
        uint256 pairBalanceBefore = address(pair).balance;

        // act
        w.skim();

        // assert
        assertEq(address(w).balance, amount, "Should have sent surplus eth to wheyfus");
        assertEq(pairBalanceBefore - address(pair).balance, amount, "Should have withdrawn surplus eth from pair");
    }

    function testItUpdatesFeeRewardPerTokenStored() public {
        // arrange
        uint96 stakeAmount = 100;
        w.feeStake(stakeAmount, 0);
        uint256 amount = 0.01 ether;
        payable(address(pair)).call{value: amount}("");
        uint256 pairBalanceBefore = address(pair).balance;

        // act
        w.skim();

        // assert
        assertEq(
            w.feeRewardPerTokenStored(), (amount * 1e18) / stakeAmount, "Should have updated fee reward per token stored"
        );
    }

    function testItSkipsUpdateIfZeroFees() public {
        // act
        uint256 pairBalanceBefore = address(pair).balance;
        uint256 fees = w.skim();

        // assert
        assertEq(fees, 0, "Should not have withdrawn any eth");
        assertEq(pairBalanceBefore - address(pair).balance, 0, "Should not have withdrawn any eth");
    }
}
