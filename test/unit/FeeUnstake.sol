// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../Fixture.t.sol";

contract FeeUnstakeTest is Fixture {
    uint96 public amount;
    uint256 public tokenId;

    receive() external payable {}

    function setUp() public {
        amount = 1e18;
        deal(address(lp), address(this), amount);
        tokenId = w.feeStake(amount, 1);
    }

    function testItTransfersFees() public {
        // arrange
        uint256 rewardAmount = 0.001 ether;
        payable(address(pair)).call{value: rewardAmount}("");
        uint256 balanceBefore = address(this).balance;
        w.skim();
        skip(30 days);

        // act
        w.feeUnstake(tokenId);

        // assert
        assertApproxEqAbs(address(this).balance - balanceBefore, rewardAmount, 1, "Should have withdrawn fees");
    }

    function testItTransfersLpTokens() public {
        // act
        skip(30 days);
        w.feeUnstake(tokenId);

        // assert
        assertEq(lp.balanceOf(address(this)), amount, "Should have withdrawn lp tokens");
    }

    function testItDecreasesStakedTotalSupply() public {
        // act
        skip(30 days);
        w.feeUnstake(tokenId);

        // assert
        assertEq(w.feeStakedTotalSupply(), 0, "Should have decreased total supply");
    }

    function testItUpdatesRewardPerTokenStored() public {
        // arrange
        uint256 rewardAmount = 0.01234 ether;
        uint256 expectedRewardPerTokenStored = (rewardAmount * 1e18) / w.feeStakedTotalSupply();
        payable(address(pair)).call{value: rewardAmount}("");
        skip(30 days);

        // act
        w.feeUnstake(tokenId);

        // assert
        assertEq(
            w.feeRewardPerTokenStored(), expectedRewardPerTokenStored, "Should have updated reward per token stored"
        );
    }

    function testItBurnsBondToken() public {
        // act
        skip(30 days);
        w.feeUnstake(tokenId);

        // assert
        vm.expectRevert("NOT_MINTED");
        feeB.ownerOf(tokenId);
    }

    function testItCannotWithdrawBondThatHasntMatured() public {
        // act
        skip(7 days - 1);
        vm.expectRevert("Bond not matured");
        w.feeUnstake(tokenId);
    }

    function testItCannotWithdrawBondYouDontOwn() public {
        // act
        vm.prank(babe);
        vm.expectRevert("Not owner");
        w.feeUnstake(tokenId);
    }

    function testItTransfersCorrectAmountOfFees() public {
        // act
        vm.startPrank(babe);
        skip(1 days);

        deal(address(lp), babe, amount, true);
        tokenId = w.feeStake(amount, 3);

        uint256 rewardAmount = 0.54321 ether;
        deal(address(pair), rewardAmount);

        uint256 totalSupply = w.feeStakedTotalSupply();
        skip(112 days);
        w.feeUnstake(tokenId);
        vm.stopPrank();

        // assert
        uint256 virtualAmount = ((uint256(w.feeBonds(tokenId).depositAmount) * 1.5e18) / 1e18);
        uint256 expectedReward = (rewardAmount * virtualAmount) / totalSupply;

        assertApproxEqAbs(babe.balance, expectedReward, 2, "Should have withdrawn correct amount of fees");
    }
}
