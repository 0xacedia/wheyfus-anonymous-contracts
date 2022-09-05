// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../Fixture.t.sol";

contract RewardPerTokenTest is Fixture {
    using stdStorage for StdStorage;

    function setUp() public {}

    function testItStartsAt0() public {
        // assert
        assertEq(w.rewardPerToken(), 0, "Should have init'd to 0");
    }

    function testItReturnsCorrectAmount() public {
        skip(333);
        uint96 amount = 100;
        deal(address(lp), address(this), amount);
        w.optionStake(amount, 1);
        uint256 lastUpdateTime = block.timestamp;
        skip(999);

        // assert
        assertEq(
            w.rewardPerToken(),
            (((block.timestamp - lastUpdateTime) * w.rewardRate() * 1e18) / w.optionStakedTotalSupply()),
            "Should have calculated correct reward per token"
        );
    }

    function testItReturnsMaxIfTimestampIsPastFinishAt() public {
        // arrange
        vm.warp(w.startAt());
        uint96 amount = 100;
        deal(address(lp), address(this), amount);
        w.optionStake(amount, 1);
        vm.warp(w.finishAt() * 2);

        // assert
        assertEq(
            w.rewardPerToken(),
            (1e18 * w.rewardRate() * w.REWARD_DURATION()) / w.optionStakedTotalSupply(),
            "Should calculate max rewards if timestamp is past finishAt"
        );
    }

    function testItReturnsMaxIfLastUpdateTimeIsGreaterThanFinishAt() public {
        // arrange
        vm.warp(w.startAt());
        uint96 amount = 100;
        deal(address(lp), address(this), amount, true);
        uint256 tokenId = w.optionStake(amount, 1);
        uint256 optionStakedTotalSupply = w.optionStakedTotalSupply();
        vm.warp(w.finishAt() * 2);
        w.optionUnstake(tokenId);

        // assert
        assertEq(w.lastUpdateTime(), w.finishAt() * 2, "Should have set last updated at");

        assertEq(
            w.rewardPerToken(),
            (1e18 * w.rewardRate() * w.REWARD_DURATION()) / optionStakedTotalSupply,
            "Should calculate max rewards if last update time is past finishAt"
        );
    }
}
