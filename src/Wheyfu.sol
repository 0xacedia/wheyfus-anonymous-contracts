// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC721, ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {ERC721A} from "ERC721A/ERC721A.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {LSSVMPairMissingEnumerableETH} from "lssvm/LSSVMPairMissingEnumerableETH.sol";
import {PuttyV2} from "putty-v2/PuttyV2.sol";
import {PuttyV2Handler, IPuttyV2Handler} from "putty-v2/PuttyV2Handler.sol";

import {TokenUri} from "./TokenUri.sol";
import {MintBurnToken} from "./MintBurnToken.sol";
import {OptionBonding} from "./OptionBonding.sol";
import {FeeBonding} from "./FeeBonding.sol";

contract Wheyfu is FeeBonding, OptionBonding, ERC721, ERC721TokenReceiver, PuttyV2Handler {
    /**
     * @notice The max supply of wheyfus.
     * @dev 9k for yield farming, 4.5k for free mint, 1.5k for team.
     */
    uint256 public constant MAX_SUPPLY = 15_000;

    /**
     * @notice Whether or not the whitelist can be modified.
     */
    bool public closedWhitelist = false;

    /**
     * @notice The total whitelisted supply.
     * @dev This should never exceed the max supply.
     */
    uint256 public whitelistedSupply;

    /**
     * @notice The total minted supply.
     */
    uint256 public totalSupply;

    /**
     * @notice Mapping of address -> whitelist amount.
     */
    mapping(address => uint256) public mintWhitelist;

    /**
     * @notice The sudoswap pool.
     */
    LSSVMPairMissingEnumerableETH public pair;

    /**
     * @notice The address of the contract that constructs the tokenURI.
     */
    TokenUri public tokenUri;

    /**
     * @notice Emitted when liquidity is added.
     * @param tokenAmount The amount of eth that was added.
     * @param nftAmount The amount of nfts that were added.
     * @param shares The amount of shares that were minted.
     */
    event AddLiquidity(uint256 tokenAmount, uint256 nftAmount, uint256 shares);

    /**
     * @notice Emitted when liquidity is removed.
     * @param tokenAmount The amount of eth that was removed.
     * @param nftAmount The amount of nfts that were removed.
     * @param shares The amount of shares that were burned.
     */
    event RemoveLiquidity(uint256 tokenAmount, uint256 nftAmount, uint256 shares);

    // solhint-disable-next-line
    receive() external payable {}

    constructor(address _lpToken, address _callOptionToken, address _putty, address _weth)
        ERC721("Wheyfus anonymous :3", "UwU")
        OptionBonding(_lpToken, _callOptionToken, _putty, _weth)
        FeeBonding(_lpToken)
    {}

    /**
     * @notice Sets the sudoswap pool address.
     * @param _pair The sudoswap pool.
     */
    function setPair(address payable _pair) public onlyOwner {
        pair = LSSVMPairMissingEnumerableETH(_pair);
        _setPair(_pair);
    }

    /**
     * @notice Sets the tokenURI contract.
     * @param _tokenUri The tokenURI contract.
     */
    function setTokenUri(address _tokenUri) public onlyOwner {
        tokenUri = TokenUri(_tokenUri);
    }

    /**
     * @notice Closes the whitelist.
     */
    function closeWhitelist() public onlyOwner {
        closedWhitelist = true;
    }

    /**
     * @notice Whitelists a minter so that they can mint a certain amount.
     * @param target The address to whitelist.
     * @param amount The amount to whitelist them for.
     */
    function whitelistMinter(address target, uint256 amount) public onlyOwner {
        // check whitelist is not closed
        require(!closedWhitelist, "Whitelist has been closed");

        // check whitelisted supply + amount is less than the max supply
        require(whitelistedSupply + amount < MAX_SUPPLY, "Max supply already reached");

        // increment/decrement the whitelistedSupply
        uint256 oldAmount = mintWhitelist[target];
        whitelistedSupply -= oldAmount;
        whitelistedSupply += amount;

        // save the new whitelist amount to the target
        mintWhitelist[target] = amount;
    }

    /**
     * MINTING FUNCTIONS
     */

    /**
     * @notice Mints a certain amount of nfts to an address.
     * @param amount The amount of nfts to mint.
     * @param to Who to mint the nfts to.
     */
    function mintTo(uint256 amount, address to) public returns (uint256) {
        return _mintTo(amount, to, msg.sender);
    }

    /**
     * @notice Mints a certain amount of nfts to msg.sender.
     * @param amount The amount of nfts to mint.
     */
    function mint(uint256 amount) public returns (uint256) {
        mintTo(amount, msg.sender);

        return totalSupply;
    }

    /**
     * @notice Mints a certain amount of nfts to an address from an account.
     * @param amount The amount of nfts to mint.
     * @param to Who to mint the nfts to.
     * @param from Who to mint the nfts from.
     */
    function _mintTo(uint256 amount, address to, address from) internal returns (uint256) {
        // check that the from account is whitelisted to mint the amount
        require(mintWhitelist[from] >= amount, "Not whitelisted for this amount");

        // loop through and mint N nfts to the to account
        for (uint256 i = totalSupply; i < totalSupply + amount; i++) {
            _mint(to, i + 1);
        }

        // increase the balance of the to account
        _balanceOf[to] += amount;

        // increaset the total supply
        totalSupply += amount;

        // decrease the whitelisted amount from the from account
        mintWhitelist[from] -= amount;

        return totalSupply;
    }

    /**
     * @notice Mints a particular nft to an account.
     * @param to Who to mint the nft to.
     * @param id The id of the nft to mint.
     */
    function _mint(address to, uint256 id) internal override {
        require(to != address(0), "INVALID_RECIPIENT");
        require(_ownerOf[id] == address(0), "ALREADY_MINTED");

        _ownerOf[id] = to;

        emit Transfer(address(0), to, id);
    }

    /**
     * SUDOSWAP POOL FUNCTIONS
     */

    /**
     * @notice adds liquidity to the shared sudoswap pool and mints lp tokens.
     * @dev updates the sudo reserves.
     * @param tokenIds the tokenIds of the nfts to send to the sudoswap pool.
     * @param minPrice the min price to lp at.
     * @param maxPrice the max price to lp at.
     */
    function addLiquidity(uint256[] calldata tokenIds, uint256 minPrice, uint256 maxPrice)
        public
        payable
        returns (uint256 shares)
    {
        // check current price is in between min and max
        uint256 _tokenReserves = tokenReserves();
        uint256 _nftReserves = nftReserves();
        uint256 _price = _tokenReserves > 0 && _nftReserves > 0 ? _tokenReserves / _nftReserves : 0;
        require(_price <= maxPrice && _price >= minPrice, "Price slippage");

        // update sudoswap reserves
        _updateReserves(_tokenReserves + msg.value, _nftReserves + tokenIds.length);

        // mint shares to sender
        uint256 _totalSupply = lpToken.totalSupply();
        shares =
            _totalSupply == 0
            ? msg.value * tokenIds.length
            : Math.min((_totalSupply * msg.value) / _tokenReserves, (_totalSupply * tokenIds.length) / _nftReserves);
        lpToken.mint(msg.sender, shares);

        // deposit tokens to sudoswap pool
        for (uint256 i = 0; i < tokenIds.length;) {
            _transferFrom(msg.sender, address(pair), tokenIds[i]);

            unchecked {
                i++;
            }
        }

        // deposit eth to sudoswap pool
        payable(pair).transfer(msg.value);

        emit AddLiquidity(msg.value, tokenIds.length, shares);
    }

    /**
     * @notice removes liquidity from the shared sudoswap pool and burns lp tokens.
     * @dev updates the sudo reserves.
     * @param tokenIds the tokenIds of the nfts to remove from the sudoswap pool.
     * @param minPrice the min price to remove the lp at.
     * @param maxPrice the max price to remove lp at.
     */
    function removeLiquidity(uint256[] calldata tokenIds, uint256 minPrice, uint256 maxPrice) public {
        // check current price is in between min and max
        uint256 _price = price();
        require(_price <= maxPrice && _price >= minPrice, "Price slippage");

        // update sudoswap reserves
        uint256 _tokenReserves = tokenReserves();
        uint256 _nftReserves = nftReserves();
        uint256 tokenAmount = (_tokenReserves * tokenIds.length) / _nftReserves;
        _updateReserves(_tokenReserves - tokenAmount, _nftReserves - tokenIds.length);

        // withdraw liquidity
        pair.withdrawETH(tokenAmount);
        pair.withdrawERC721(IERC721(address(this)), tokenIds);

        // burn shares
        uint256 _totalSupply = lpToken.totalSupply();
        uint256 shares = (_totalSupply * tokenIds.length) / _nftReserves;
        lpToken.burn(msg.sender, shares);

        // send tokens to user
        for (uint256 i = 0; i < tokenIds.length;) {
            _transferFrom(address(this), msg.sender, tokenIds[i]);

            unchecked {
                i++;
            }
        }

        // send eth to user
        payable(msg.sender).transfer(tokenAmount);

        emit RemoveLiquidity(tokenAmount, tokenIds.length, shares);
    }

    /**
     * @notice Getter for the token reserves in the sudoswap pool.
     */
    function tokenReserves() public view returns (uint256) {
        return pair.spotPrice();
    }

    /**
     * @notice Getter for the nft reserves in the sudoswap pool.
     */
    function nftReserves() public view returns (uint256) {
        return pair.delta();
    }

    /**
     * @notice Getter for the price in the sudoswap pool.
     */
    function price() public view returns (uint256) {
        uint256 _tokenReserves = tokenReserves();
        uint256 _nftReserves = nftReserves();

        return _tokenReserves > 0 && _nftReserves > 0 ? _tokenReserves / _nftReserves : 0;
    }

    /**
     * @notice Updates the sudoswap pool's virtual reserves.
     * @param _tokenReserves The new token reserves.
     * @param _nftReserves The new nft reserves.
     */
    function _updateReserves(uint256 _tokenReserves, uint256 _nftReserves) internal {
        pair.changeSpotPrice(uint128(_tokenReserves));
        pair.changeDelta(uint128(_nftReserves));
    }

    /**
     * PERIPHERY FUNCTIONS
     */

    /**
     * @notice wrapper around addLiquidity() and stake()
     * @param tokenIds the tokenIds of the nfts to send to the sudoswap pool.
     * @param minPrice the min price to lp at.
     * @param maxPrice the max price to lp at.
     * @param termIndex index into the terms array which tells how long to stake for.
     */
    function addLiquidityAndStake(uint256[] calldata tokenIds, uint256 minPrice, uint256 maxPrice, uint256 termIndex)
        public
        payable
        returns (uint256 tokenId)
    {
        uint256 shares = addLiquidity(tokenIds, minPrice, maxPrice);
        tokenId = stake(uint96(shares), termIndex);
    }

    /**
     * OVERRIDE FUNCTIONS
     */

    /**
     * @notice when the call option is exercised putty will call this function. it mints
     * nfts to the exerciser.
     * @dev    should only be callable by putty. we defer the mint to here instead of on
     * call option creation to save gas.
     */
    function onExercise(PuttyV2.Order memory order, address exerciser, uint256[] memory floorAssetTokenIds)
        public
        override
    {
        // if we were the maker of the order then it must be a short call and the tokens
        // need to be minted because we initially skipped transferring them in.
        if (order.maker == address(this) && msg.sender == address(putty)) {
            _mintTo(type(uint256).max - order.erc721Assets[0].tokenId, exerciser, address(putty));
        }
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(IPuttyV2Handler).interfaceId || super.supportsInterface(interfaceId);
    }

    function _transferFrom(address from, address to, uint256 id) internal virtual {
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

        require(
            to.code.length == 0
                || ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, "") == ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public override {
        // if minting an option then no need to transfer
        // (means that we need to mint onExercise instead)
        if (mintingOption == 2) {
            return;
        }

        // if putty is trying to send tokens for a tokenId greater than max supply
        // then skip. the only way this should ever be reachable is if the bonding contract
        // minted an option. otherwise putty should never have received tokens with ids greater
        // than the max supply.
        if (from == address(putty) && tokenId > MAX_SUPPLY && msg.sender == address(putty)) {
            return;
        }

        super.safeTransferFrom(from, to, tokenId);
    }

    function tokenURI(uint256 id) public view virtual override returns (string memory) {
        return tokenUri.tokenURI(id);
    }
}
