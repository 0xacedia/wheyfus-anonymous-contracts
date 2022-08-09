// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../Fixture.t.sol";

contract TokenUriTest is Fixture {
    function setUp() public {}

    function testItReturnsTokenUriForNft() public {
        string memory tokenUri = w.tokenURI(1);

        console.log(tokenUri);
    }

    function testItReturnsTokenUriForCallOption() public {
        string memory tokenUri = w.tokenURI(type(uint256).max - 20);

        console.log(tokenUri);
    }
}
