// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../Fixture.t.sol";

contract OptionUnstakeTest is Fixture {
    uint96 public amount;
    uint256 public tokenId;

    function setUp() public {
        amount = 1e18;
        deal(address(lp), address(this), amount, true);
        tokenId = w.optionStake(amount, 1);
    }

    function testItTransfersCallOptionTokens() public {
        // act
        skip(30 days);
        w.optionUnstake(tokenId);

        // assert
        assertApproxEqAbs(
            co.balanceOf(address(this)), w.rewardRate() * 30 days, 2, "Should have withdrawn call option tokens"
        );
    }

    function testItTransfersLpTokens() public {
        // act
        skip(30 days);
        w.optionUnstake(tokenId);

        // assert
        assertEq(lp.balanceOf(address(this)), amount, "Should have withdrawn lp tokens");
    }

    function testItDecreasesStakedTotalSupply() public {
        // act
        skip(30 days);
        w.optionUnstake(tokenId);

        // assert
        assertEq(w.optionStakedTotalSupply(), 0, "Should have decreased total supply");
    }

    function testItUpdatesLastUpdateTime() public {
        // act
        skip(30 days);
        w.optionUnstake(tokenId);

        // assert
        assertEq(w.lastUpdateTime(), block.timestamp, "Should have updated last update time");
    }

    function testItUpdatesRewardPerTokenStored() public {
        // arrange
        uint256 duration = 30 days;
        uint256 expectedRewardPerTokenStored = ((w.rewardRate() * duration * 1e18) / w.optionStakedTotalSupply());

        // act
        skip(duration);
        w.optionUnstake(tokenId);

        // assert
        assertEq(w.optionRewardPerTokenStored(), expectedRewardPerTokenStored, "Should have updated last update time");
    }

    function testItBurnsBondToken() public {
        // act
        skip(30 days);
        w.optionUnstake(tokenId);

        // assert
        vm.expectRevert("NOT_MINTED");
        w.ownerOf(tokenId);
    }

    function testItCannotWithdrawBondThatHasntMatured() public {
        // act
        skip(7 days - 1);
        vm.expectRevert("Bond not matured");
        w.optionUnstake(tokenId);
    }

    function testItCannotWithdrawBondYouDontOwn() public {
        // act
        vm.prank(babe);
        vm.expectRevert("Not owner");
        w.optionUnstake(tokenId);
    }

    function testItTransfersCorrectAmountOfCallOptionTokens() public {
        // act
        vm.startPrank(babe);
        skip(1 days);

        deal(address(lp), babe, amount, true);
        tokenId = w.optionStake(amount, 3);

        uint256 totalSupply = w.optionStakedTotalSupply();
        skip(112 days);
        w.optionUnstake(tokenId);
        vm.stopPrank();

        // assert
        uint256 virtualAmount = ((uint256(w.bonds(tokenId).depositAmount) * 1.5e18) / 1e18);
        uint256 expectedReward = (w.rewardRate() * 112 days * virtualAmount) / totalSupply;

        assertApproxEqAbs(
            co.balanceOf(babe), expectedReward, 2, "Should have withdrawn correct amount of call option tokens"
        );
    }
}
