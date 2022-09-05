// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "../Fixture.t.sol";

contract OptionStakeUnstakeTest is Fixture, ERC721TokenReceiver {
    struct Stake {
        uint96 amount;
        uint16 skip;
        uint16 duration;
    }

    uint256[] public tokenIds;

    receive() external payable {}

    function setUp() public {}

    function testOptionStakeUnstake(Stake[] memory stakes) public {
        uint256[] memory withdrawTimes = new uint256[](stakes.length);
        uint256[] memory totalEarned = new uint256[](stakes.length);
        bool[] memory withdrawn = new bool[](stakes.length);
        uint256 totalStaked = 0;
        uint256 timeElapsedSinceLastCheck = 0;
        uint256 totalTimeElapsed = 0;

        for (uint256 i = 0; i < stakes.length; i++) {
            stakes[i].amount = uint96(bound(stakes[i].amount, 1, type(uint32).max));

            for (uint256 j = 0; j < i; j++) {
                if (withdrawn[j]) {
                    continue;
                }

                uint256 amount = stakes[j].amount;
                totalEarned[j] += (amount * ((timeElapsedSinceLastCheck * w.rewardRate() * 1e18) / totalStaked)) / 1e18;

                assertApproxEqAbs(w.optionEarned(j + 1), totalEarned[j], 10, "Should have accrued rewards correctly");
            }

            for (uint256 k = 0; k < i; k++) {
                if (withdrawTimes[k] < block.timestamp && !withdrawn[k]) {
                    address wPerson = address(uint160(type(uint256).max - k));
                    vm.startPrank(wPerson);
                    w.optionUnstake(k + 1);
                    vm.stopPrank();

                    withdrawn[k] = true;
                    totalStaked -= stakes[k].amount;
                }
            }

            Stake memory stake = stakes[i];

            address person = address(uint160(type(uint256).max - i));
            vm.startPrank(person);

            deal(address(lp), person, stake.amount, true);
            w.optionStake(stake.amount, 0);
            skip(1 days + stake.skip);
            timeElapsedSinceLastCheck = 1 days + stake.skip;
            totalTimeElapsed += 1 days + stake.skip;
            withdrawTimes[i] = 1 days + stake.skip + stake.duration;
            totalStaked += stake.amount;

            vm.stopPrank();

            assertEq(w.optionStakedTotalSupply(), totalStaked, "Should have increased total staked");
        }

        uint256 total = 0;
        for (uint256 i = 0; i < totalEarned.length; i++) {
            total += totalEarned[i];
        }

        assertApproxEqAbs(
            w.rewardRate() * (totalTimeElapsed - timeElapsedSinceLastCheck),
            total,
            stakes.length,
            "Should have accrued total rewards"
        );
    }
}
