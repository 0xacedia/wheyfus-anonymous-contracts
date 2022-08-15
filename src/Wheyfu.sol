// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC721, ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {ERC721A} from "ERC721A/ERC721A.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {LSSVMPairMissingEnumerableETH} from "lssvm/LSSVMPairMissingEnumerableETH.sol";
import {Bonding} from "./Bonding.sol";
import {PuttyV2} from "putty-v2/PuttyV2.sol";
import {PuttyV2Handler, IPuttyV2Handler} from "putty-v2/PuttyV2Handler.sol";

import {TokenUri} from "./TokenUri.sol";
import {MintBurnToken} from "./MintBurnToken.sol";

contract Wheyfu is Bonding, ERC721, ERC721TokenReceiver, PuttyV2Handler {
    event AddLiquidity(uint256 tokenAmount, uint256 nftAmount, uint256 shares);
    event RemoveLiquidity(
        uint256 tokenAmount,
        uint256 nftAmount,
        uint256 shares
    );

    uint256 public constant MAX_SUPPLY = 10_000;

    bool public closedWhitelist = false;
    uint256 public whitelistedSupply;
    uint256 public totalSupply;
    mapping(address => uint256) public mintWhitelist;

    LSSVMPairMissingEnumerableETH public pair;
    TokenUri public tokenUri;

    receive() external payable {}

    constructor(
        address _lpToken,
        address _callOptionToken,
        address _putty,
        address _weth
    )
        ERC721("Wheyfus anonymous :3", "UwU")
        Bonding(_lpToken, _callOptionToken, _putty, _weth)
    {}

    function setPair(address payable _pair) public onlyOwner {
        pair = LSSVMPairMissingEnumerableETH(_pair);
    }

    function setTokenUri(address _tokenUri) public onlyOwner {
        tokenUri = TokenUri(_tokenUri);
    }

    function closeWhitelist() public onlyOwner {
        closedWhitelist = true;
    }

    function whitelistMinter(address target, uint256 amount) public onlyOwner {
        require(!closedWhitelist, "Whitelist has been closed");
        require(
            whitelistedSupply + amount < MAX_SUPPLY,
            "Max supply already reached"
        );

        uint256 oldAmount = mintWhitelist[target];
        whitelistedSupply = oldAmount > amount
            ? whitelistedSupply - (oldAmount - amount)
            : whitelistedSupply + (amount - oldAmount);

        mintWhitelist[target] = amount;
    }

    /**
            MINTING FUNCTIONS
     */

    function mintTo(uint256 amount, address to) public returns (uint256) {
        return _mintTo(amount, to, msg.sender);
    }

    function mint(uint256 amount) public returns (uint256) {
        mintTo(amount, msg.sender);

        return totalSupply;
    }

    function _mintTo(
        uint256 amount,
        address to,
        address from
    ) internal returns (uint256) {
        require(
            mintWhitelist[from] >= amount,
            "Not whitelisted for this amount"
        );

        for (uint256 i = totalSupply; i < totalSupply + amount; i++) {
            _mint(to, i + 1);
        }

        totalSupply += amount;
        mintWhitelist[from] -= amount;

        _balanceOf[to] += amount;

        return totalSupply;
    }

    function _mint(address to, uint256 id) internal override {
        require(to != address(0), "INVALID_RECIPIENT");
        require(_ownerOf[id] == address(0), "ALREADY_MINTED");

        _ownerOf[id] = to;

        emit Transfer(address(0), to, id);
    }

    /**
            SUDOSWAP POOL FUNCTIONS
     */

    /**
        @notice adds liquidity to the shared sudoswap pool and mints lp tokens.
        @dev updates the sudo reserves.
        @param tokenIds the tokenIds of the nfts to send to the sudoswap pool.
        @param minPrice the min price to lp at.
        @param maxPrice the max price to lp at.
     */
    function addLiquidity(
        uint256[] calldata tokenIds,
        uint256 minPrice,
        uint256 maxPrice
    ) public payable returns (uint256 shares) {
        shares = _addLiquidity(tokenIds, minPrice, maxPrice, true);
    }

    function _addLiquidity(
        uint256[] calldata tokenIds,
        uint256 minPrice,
        uint256 maxPrice,
        bool mintShares
    ) internal returns (uint256 shares) {
        // check current price is in between min and max
        uint256 _tokenReserves = tokenReserves();
        uint256 _nftReserves = nftReserves();
        uint256 _price = _tokenReserves > 0 && _nftReserves > 0
            ? _tokenReserves / _nftReserves
            : 0;
        require(_price <= maxPrice && _price >= minPrice, "Price slippage");

        // update sudoswap reserves
        _updateReserves(
            _tokenReserves + msg.value,
            _nftReserves + tokenIds.length
        );

        // deposit tokens to sudoswap pool
        for (uint256 i = 0; i < tokenIds.length; ) {
            _transferFrom(msg.sender, address(pair), tokenIds[i]);

            unchecked {
                i++;
            }
        }

        // mint shares to sender
        uint256 _totalSupply = lpToken.totalSupply();
        shares = _totalSupply == 0
            ? msg.value * tokenIds.length
            : Math.min(
                (msg.value * _totalSupply) / _tokenReserves,
                (tokenIds.length * _totalSupply) / _nftReserves
            );
        lpToken.mint(msg.sender, shares);

        // deposit eth to sudoswap pool
        payable(pair).transfer(msg.value);

        emit AddLiquidity(msg.value, tokenIds.length, shares);
    }

    /**
        @notice removes liquidity from the shared sudoswap pool and burns lp tokens.
        @dev updates the sudo reserves.
        @param tokenIds the tokenIds of the nfts to remove from the sudoswap pool.
        @param minPrice the min price to remove the lp at.
        @param maxPrice the max price to remove lp at.
     */
    function removeLiquidity(
        uint256[] calldata tokenIds,
        uint256 minPrice,
        uint256 maxPrice
    ) public {
        // check current price is in between min and max
        uint256 _price = price();
        require(_price <= maxPrice && _price >= minPrice, "Price slippage");

        // update sudoswap reserves
        uint256 _tokenReserves = tokenReserves();
        uint256 _nftReserves = nftReserves();
        uint256 tokenAmount = (_tokenReserves * tokenIds.length) / _nftReserves;
        _updateReserves(
            _tokenReserves - tokenAmount,
            _nftReserves - tokenIds.length
        );

        // withdraw liquidity
        pair.withdrawETH(tokenAmount);
        pair.withdrawERC721(IERC721(address(this)), tokenIds);

        // send tokens to user
        for (uint256 i = 0; i < tokenIds.length; ) {
            _transferFrom(address(this), msg.sender, tokenIds[i]);

            unchecked {
                i++;
            }
        }

        // burn shares
        uint256 _totalSupply = lpToken.totalSupply();
        uint256 shares = (_totalSupply * tokenIds.length) / _nftReserves;
        lpToken.burn(msg.sender, shares);

        // send eth to user
        payable(msg.sender).transfer(tokenAmount);

        emit RemoveLiquidity(tokenAmount, tokenIds.length, shares);
    }

    function tokenReserves() public view returns (uint256) {
        return pair.spotPrice();
    }

    function nftReserves() public view returns (uint256) {
        return pair.delta();
    }

    function price() public view returns (uint256) {
        uint256 _tokenReserves = tokenReserves();
        uint256 _nftReserves = nftReserves();

        return
            _tokenReserves > 0 && _nftReserves > 0
                ? _tokenReserves / _nftReserves
                : 0;
    }

    function _updateReserves(uint256 _tokenReserves, uint256 _nftReserves)
        internal
    {
        pair.changeSpotPrice(uint128(_tokenReserves));
        pair.changeDelta(uint128(_nftReserves));
    }

    /**
        PERIPHERY FUNCTIONS
     */

    /**
        @notice wrapper around addLiquidity() and stake()
        @param tokenIds the tokenIds of the nfts to send to the sudoswap pool.
        @param minPrice the min price to lp at.
        @param maxPrice the max price to lp at.
        @param termIndex index into the terms array which tells how long to stake for. 
      */
    function addLiquidityAndStake(
        uint256[] calldata tokenIds,
        uint256 minPrice,
        uint256 maxPrice,
        uint256 termIndex
    ) public payable returns (uint256 tokenId) {
        uint256 shares = _addLiquidity(tokenIds, minPrice, maxPrice, false);
        tokenId = _stake(uint96(shares), termIndex, false);
    }

    /**
            OVERRIDE FUNCTIONS
     */

    /**
        @notice when the call option is exercised putty will call this function. it mints
                nfts to the exerciser.
        @dev    should only be callable by putty. we defer the mint to here instead of on 
                call option creation to save gas.
     */
    function onExercise(
        PuttyV2.Order memory order,
        address exerciser,
        uint256[] memory floorAssetTokenIds
    ) public override {
        // if we were the maker of the order then it must be a short call and the tokens
        // need to be minted because we initially skipped transferring them in.
        if (order.maker == address(this) && msg.sender == address(putty)) {
            _mintTo(
                type(uint256).max - order.erc721Assets[0].tokenId,
                exerciser,
                address(putty)
            );
        }
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override
        returns (bool)
    {
        return
            interfaceId == type(IPuttyV2Handler).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function _transferFrom(
        address from,
        address to,
        uint256 id
    ) internal virtual {
        require(from == _ownerOf[id], "WRONG_FROM");

        require(to != address(0), "INVALID_RECIPIENT");

        // Underflow of the sender's balance is impossible because we check for
        // ownership above and the recipient's balance can't realistically overflow.
        unchecked {
            _balanceOf[from]--;

            _balanceOf[to]++;
        }

        _ownerOf[id] = to;

        delete getApproved[id];

        emit Transfer(from, to, id);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
        // if minting an option then no need to transfer
        // (means that we need to mint onExercise instead)
        if (mintingOption == 2) {
            return;
        }

        // if putty is trying to send tokens for a tokenId greater than max supply
        // then skip. the only way this should ever be reachable is if the bonding contract
        // minted an option. otherwise putty should never have received tokens with ids greater
        // than the max supply.
        if (
            from == address(putty) &&
            tokenId > MAX_SUPPLY &&
            msg.sender == address(putty)
        ) {
            return;
        }

        super.safeTransferFrom(from, to, tokenId);
    }

    function tokenURI(uint256 id)
        public
        view
        virtual
        override
        returns (string memory)
    {
        return tokenUri.tokenURI(id);
    }
}
