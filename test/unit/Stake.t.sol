// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../Fixture.t.sol";

contract StakeTest is Fixture {
    uint96 public amount;

    function setUp() public {
        amount = 100;
        deal(address(lp), address(this), amount);
    }

    function testItBurnsLpTokens() public {
        // arrange
        uint256 balanceBefore = lp.balanceOf(address(this));

        // act
        w.stake(amount, 0);

        // assert
        assertEq(
            balanceBefore - lp.balanceOf(address(this)),
            amount,
            "Should have burned lp tokens"
        );
    }

    function testItUpdatesTotalStakedSupply() public {
        // arrange
        uint256 termIndex = 1;
        uint256 termBooster = w.termBoosters(termIndex);

        // act
        w.stake(amount, termIndex);

        // assert
        assertEq(
            w.stakedTotalSupply(),
            (amount * termBooster) / 1e18,
            "Should have updated staked total supply"
        );
    }

    function testItUpdatesLastUpdateTime() public {
        // arrange
        skip(100);

        // act
        w.stake(amount, 1);

        // assert
        assertEq(
            w.lastUpdateTime(),
            block.timestamp,
            "Should have updated last update time"
        );
    }

    function testItSavesBondDetails() public {
        // arrange
        uint256 tokenId = w.stake(amount, 1);

        // assert
        assertEq(
            w.bonds(tokenId).termIndex,
            1,
            "Should have saved bond term index"
        );

        assertEq(
            w.bonds(tokenId).depositTimestamp,
            block.timestamp,
            "Should have saved bond deposit timestamp"
        );

        assertEq(
            w.bonds(tokenId).depositAmount,
            amount,
            "Should have saved bond deposit amount"
        );

        assertEq(
            w.bonds(tokenId).rewardPerTokenCheckpoint,
            0,
            "Should have inited staked bond reward per token paid"
        );
    }

    function testItSetsBondRewardPerTokenCheckpointAndRewardPerTokenStored()
        public
    {
        // arrange
        uint256 duration = 50;
        w.stake(amount, 1);
        skip(duration);
        deal(address(lp), address(this), amount);
        uint256 expectedRewardPerTokenPaid = (w.rewardRate() *
            duration *
            1e18) / ((amount * w.termBoosters(1)) / 1e18);

        // act
        uint256 tokenId = w.stake(amount, 1);

        // assert
        assertEq(
            w.bonds(tokenId).rewardPerTokenCheckpoint,
            expectedRewardPerTokenPaid,
            "Should have updated staked bond reward per token paid"
        );

        assertEq(
            w.rewardPerTokenStored(),
            expectedRewardPerTokenPaid,
            "Should have stored reward per token"
        );
    }

    function testItMintsBondNft() public {
        // arrange
        uint256 tokenId = w.stake(amount, 1);

        // assert
        assertEq(
            b.ownerOf(tokenId),
            address(this),
            "Should have minted bond NFT"
        );

        assertEq(
            w.totalBondSupply(),
            1,
            "Should incremented total bond supply"
        );
    }
}
