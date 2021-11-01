// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "hardhat/console.sol";
import "../tokens/MirroredERC721.sol";
import "../interfaces/IERC721Mirrored.sol";

contract ERC721SwapAgent is Initializable, OwnableUpgradeable, ERC721HolderUpgradeable {
    mapping(uint256 => mapping(address => bool)) public registeredToken;
    mapping(bytes32 => bool) public filledSwap;
    mapping(uint256 => mapping(address => address)) public swapMappingIncoming;
    mapping(uint256 => mapping(address => address)) public swapMappingOutgoing;
    mapping(string => mapping(bytes32 => bool)) public filledERC721Tx;

    /* Events from outgoing messages */
    event SwapPairRegister(
        address indexed sponsor,
        address indexed tokenAddress,
        string tokenName,
        string tokenSymbol,
        uint256 toChainId,
        uint256 feeAmount
    );

    event SwapStarted(
        address indexed tokenAddr,
        address indexed sender,
        address indexed recipient,
        uint256 dstChainId,
        uint256 tokenId,
        uint256 feeAmount
    );

    event BackwardSwapStarted(
        address indexed mirroredTokenAddr,
        address indexed sender,
        address indexed recipient,
        uint256 dstChainId,
        uint256 tokenId,
        uint256 feeAmount
    );

    /* Events from incoming messages */
    event SwapPairCreated(
      bytes32 indexed registerTxHash,
      address indexed fromTokenAddr,
      address indexed mirroredTokenAddr,
      uint256 fromChainId,
      string tokenSymbol,
      string tokenName
    );

    event SwapFilled(
        bytes32 indexed swapTxHash,
        address indexed fromTokenAddr,
        address indexed recipient,
        address mirroredTokenAddr,
        uint256 fromChainId,
        uint256 tokenId
    );

    event BackwardSwapFilled(
        bytes32 indexed swapTxHash,
        address indexed tokenAddr,
        address indexed recipient,
        uint256 fromChainId,
        uint256 tokenId
    );

    function initialize() public initializer {
        __Ownable_init();
    }

    function createSwapPair(
        bytes32 registerTxHash,
        address fromTokenAddr,
        uint256 fromChainId,
        string calldata tokenName,
        string calldata tokenSymbol
    ) public {
        require(
            swapMappingIncoming[fromChainId][fromTokenAddr] == address(0x0),
            "ERC721SwapAgent::createSwapPair:: mirrored token is already deployed"
        );

        MirroredERC721 mirrored = new MirroredERC721();
        mirrored.initialize(tokenName, tokenSymbol);
        swapMappingIncoming[fromChainId][fromTokenAddr] = address(mirrored);
        swapMappingOutgoing[fromChainId][address(mirrored)] = fromTokenAddr;

        emit SwapPairCreated(registerTxHash, fromTokenAddr, address(mirrored), fromChainId, tokenSymbol, tokenName);
    }

    function registerSwapPair(address tokenAddr, uint256 chainId) external payable {
        require(
            !registeredToken[chainId][tokenAddr],
            "ERC721SwapAgent::registerSwapPair:: token is already registered"
        );
        IERC721MetadataUpgradeable meta = IERC721MetadataUpgradeable(
            tokenAddr
        );

        string memory name = meta.name();
        string memory symbol = meta.symbol();

        require(
            bytes(name).length > 0,
            "ERC721SwapAgent::registerSwapPair:: empty token name"
        );
        require(
            bytes(symbol).length > 0,
            "ERC721SwapAgent::registerSwapPair:: empty token symbol"
        );

        registeredToken[chainId][tokenAddr] = true;

        emit SwapPairRegister(msg.sender, tokenAddr, name, symbol, chainId, msg.value);
    }

    function swap(address tokenAddr, address recipient, uint256 tokenId, uint256 dstChainId) external payable {
        console.log("[swap]: tokenAddr %s", tokenAddr);
        console.log("[swap]: recipient %s", recipient);
        console.log("[swap]: tokenId %s", tokenId);
        console.log("[swap]: dstChainId %s", dstChainId);

        // try forward swap  
        if (registeredToken[dstChainId][tokenAddr]) {
          IERC721 token = IERC721(tokenAddr);
          token.safeTransferFrom(msg.sender, address(this), tokenId);
          require(token.ownerOf(tokenId) == address(this), "ERC721SwapAgent::swap:: wrong ownership after transferfing");

          emit SwapStarted(tokenAddr, msg.sender, recipient, dstChainId, tokenId, msg.value);

          return;
        }

        // try backward swap  
        address mirroredTokenAddr = swapMappingOutgoing[dstChainId][tokenAddr];
        if (mirroredTokenAddr != address(0x0)) {
          IERC721Mirrored mirroredToken = IERC721Mirrored(mirroredTokenAddr);
          mirroredToken.burn(tokenId);

          emit BackwardSwapStarted(
              mirroredTokenAddr,
              msg.sender,
              recipient,
              dstChainId,
              tokenId,
              msg.value  
          );

          return;
        }

        revert("ERC721SwapAgent::swap:: token has no swap pair");
    }

    function fill(bytes32 swapTxHash, address fromTokenAddr, address recipient, uint256 fromChainId, uint256 tokenId, string calldata tokenURI) public {
        require(!filledSwap[swapTxHash], "ERC721SwapAgent::fill:: tx hash was already filled");
        filledSwap[swapTxHash] = true;

        // fill forward swap, it means our core server will find the related mirrored token
        // and assign the value to fromTokenAddr
        address mirroredTokenAddr = swapMappingIncoming[fromChainId][fromTokenAddr];
        if (mirroredTokenAddr != address(0x0)) {
          IERC721Mirrored mirroredToken = IERC721Mirrored(mirroredTokenAddr);
          mirroredToken.safeMint(recipient, tokenId);
          mirroredToken.setTokenURI(tokenId, tokenURI);

          // if (bytes(baseURI).length > 0) {
          //   mirroredToken.setBaseURI(tokenId, tokenURI);
          // } else if (bytes(tokenURI).length > 0) {
          //   mirroredToken.setTokenURI(tokenId, tokenURI);
          // }

          require(
            mirroredToken.ownerOf(tokenId) == recipient,
            "ERC721SwapAgent::fill:: wrong ownership after minting"
          );

          emit SwapFilled(
              swapTxHash,
              fromTokenAddr,
              recipient,
              mirroredTokenAddr,
              fromChainId,
              tokenId
          );

          return;
        }

        // fill backward swap.,it means that this token is the one users have been sent before
        // our server will find this token from the given mirrored token in the BackwardSwapStarted event
        // and assign the value to fromTokenAddr
        if (registeredToken[fromChainId][fromTokenAddr]) {
          IERC721 token = IERC721(fromTokenAddr);
          token.safeTransferFrom(address(this), recipient, tokenId);

          require(token.ownerOf(tokenId) == recipient, "ERC721SwapAgent::fill:: wrong ownership after transferfing");

          emit BackwardSwapFilled(
              swapTxHash,
              fromTokenAddr,
              recipient,
              fromChainId,
              tokenId
          );

          return;
        }

        revert("ERC721SwapAgent::fill:: token has no swap pair");
    }
}
