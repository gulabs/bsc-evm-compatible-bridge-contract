// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "hardhat/console.sol";
import "../tokens/MirroredERC721.sol";
import "../interfaces/IERC721Mirrored.sol";

contract ERC721SwapAgent is
    Initializable,
    OwnableUpgradeable,
    ERC721HolderUpgradeable
{
    // -- Error Constants --
    // ERC721SwapAgent::registerSwapPair:: token is already registered
    string private constant ERR721_REGISTER_TOKEN_EXISTS = "SA.721.1.1";
    // ERC721SwapAgent::registerSwapPair:: empty token name
    string private constant ERR721_REGISTER_EMPTY_TOKEN_NAME = "SA.721.1.2";
    // ERC721SwapAgent::registerSwapPair:: empty token symbol
    string private constant ERR721_REGISTER_EMPTY_TOKEN_SYMBOL = "SA.721.1.3";

    // ERC721SwapAgent::createSwapPair:: mirrored token is already deployed
    string private constant ERR721_CREATE_MIRRORED_EXISTS = "SA.721.2.1";

    // ERC721SwapAgent::swap:: wrong ownership after transferfing
    string private constant ERR721_FORWARD_SWAP_WRONG_OWNER = "SA.721.3.1";
    // ERC721SwapAgent::swap:: wrong ownership after transferfing
    string private constant ERR721_BACKWARD_SWAP_WRONG_OWNER = "SA.721.3.2";
    // ERC721SwapAgent::swap:: token has no swap pair
    string private constant ERR721_SWAP_NO_PAIR = "SA.721.3.3";

    // ERC721SwapAgent::fill:: tx hash was already filled
    string private constant ERR721_FILL_ALREADY_FILLED = "SA.721.4.1";
    // ERC721SwapAgent::fill:: wrong ownership after minting for forward fill
    string private constant ERR721_FORWARD_FILL_WRONG_OWNER = "SA.721.4.2";
    // ERC721SwapAgent::fill:: wrong ownership after transferfing for backward fill
    string private constant ERR721_BACKWARD_FILL_WRONG_OWNER = "SA.721.4.3";
    // ERC721SwapAgent::fill:: token has no swap pair
    string private constant ERR721_FILL_NO_PAIR = "SA.721.4.4";

    // -- Storage Variables --
    mapping(uint256 => mapping(address => bool)) public registeredToken;
    mapping(bytes32 => bool) public filledSwap;
    mapping(uint256 => mapping(address => address)) public swapMappingIncoming;
    mapping(uint256 => mapping(address => address)) public swapMappingOutgoing;

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
        string calldata baseURI_,
        string calldata tokenName,
        string calldata tokenSymbol
    ) public onlyOwner {
        require(
            swapMappingIncoming[fromChainId][fromTokenAddr] == address(0x0),
            ERR721_CREATE_MIRRORED_EXISTS
        );

        MirroredERC721 mirrored = new MirroredERC721();
        mirrored.initialize(tokenName, tokenSymbol);

        if (bytes(baseURI_).length > 0) {
            mirrored.setBaseURI(baseURI_);
        }

        swapMappingIncoming[fromChainId][fromTokenAddr] = address(mirrored);
        swapMappingOutgoing[fromChainId][address(mirrored)] = fromTokenAddr;

        emit SwapPairCreated(
            registerTxHash,
            fromTokenAddr,
            address(mirrored),
            fromChainId,
            tokenSymbol,
            tokenName
        );
    }

    function registerSwapPair(address tokenAddr, uint256 chainId)
        external
        payable
    {
        require(
            !registeredToken[chainId][tokenAddr],
            ERR721_REGISTER_TOKEN_EXISTS
        );

        registeredToken[chainId][tokenAddr] = true;
        IERC721MetadataUpgradeable meta = IERC721MetadataUpgradeable(tokenAddr);
        string memory name = meta.name();
        string memory symbol = meta.symbol();

        require(bytes(name).length > 0, ERR721_REGISTER_EMPTY_TOKEN_NAME);
        require(bytes(symbol).length > 0, ERR721_REGISTER_EMPTY_TOKEN_SYMBOL);

        emit SwapPairRegister(
            msg.sender,
            tokenAddr,
            name,
            symbol,
            chainId,
            msg.value
        );
    }

    function swap(
        address tokenAddr,
        address recipient,
        uint256 tokenId,
        uint256 dstChainId
    ) external payable {
        console.log("[swap]: tokenAddr %s", tokenAddr);
        console.log("[swap]: recipient %s", recipient);
        console.log("[swap]: tokenId %s", tokenId);
        console.log("[swap]: dstChainId %s", dstChainId);

        // try forward swap
        if (registeredToken[dstChainId][tokenAddr]) {
            IERC721 token = IERC721(tokenAddr);
            token.safeTransferFrom(msg.sender, address(this), tokenId);

            require(
                token.ownerOf(tokenId) == address(this),
                ERR721_FORWARD_SWAP_WRONG_OWNER
            );

            emit SwapStarted(
                tokenAddr,
                msg.sender,
                recipient,
                dstChainId,
                tokenId,
                msg.value
            );

            return;
        }

        // try backward swap
        address dstTokenAddr = swapMappingOutgoing[dstChainId][tokenAddr];
        if (dstTokenAddr != address(0x0)) {
            IERC721Mirrored mirroredToken = IERC721Mirrored(tokenAddr);

            mirroredToken.safeTransferFrom(msg.sender, address(this), tokenId);
            require(
                mirroredToken.ownerOf(tokenId) == address(this),
                ERR721_BACKWARD_SWAP_WRONG_OWNER
            );

            mirroredToken.burn(tokenId);

            emit BackwardSwapStarted(
                tokenAddr,
                msg.sender,
                recipient,
                dstChainId,
                tokenId,
                msg.value
            );

            return;
        }

        revert(ERR721_SWAP_NO_PAIR);
    }

    function fill(
        bytes32 swapTxHash,
        address fromTokenAddr,
        address recipient,
        uint256 fromChainId,
        uint256 tokenId,
        string calldata tokenURI
    ) public onlyOwner {
        console.log(
            "[fill]: swapTxHash %s",
            string(abi.encodePacked(swapTxHash))
        );
        console.log("[fill]: fromTokenAddr %s", fromTokenAddr);
        console.log("[fill]: recipient %s", recipient);
        console.log("[fill]: fromChainId %s", fromChainId);
        console.log("[fill]: tokenId %s", tokenId);
        console.log("[fill]: tokenURI %s", tokenURI);

        require(!filledSwap[swapTxHash], ERR721_FILL_ALREADY_FILLED);
        filledSwap[swapTxHash] = true;

        // fill forward swap, it means our core server will find the related mirrored token
        // and assign the value to fromTokenAddr
        address mirroredTokenAddr = swapMappingIncoming[fromChainId][
            fromTokenAddr
        ];
        if (mirroredTokenAddr != address(0x0)) {
            console.log("[fill]: fill forward swap");
            IERC721Mirrored mirroredToken = IERC721Mirrored(mirroredTokenAddr);
            mirroredToken.safeMint(recipient, tokenId);
            console.log("[fill]: minted");
            mirroredToken.setTokenURI(tokenId, tokenURI);
            console.log("[fill]: set token uri");

            require(
                mirroredToken.ownerOf(tokenId) == recipient,
                ERR721_FORWARD_FILL_WRONG_OWNER
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

        // fill backward swap, it means that this token is the one users have been sent before
        // our server will find this token from the given mirrored token in the BackwardSwapStarted event
        // and assign the value to fromTokenAddr
        if (registeredToken[fromChainId][fromTokenAddr]) {
            console.log("[fill]: fill backward swap");
            IERC721 token = IERC721(fromTokenAddr);
            token.safeTransferFrom(address(this), recipient, tokenId);
            console.log("[fill]: transferred back to the owner");

            require(
                token.ownerOf(tokenId) == recipient,
                ERR721_BACKWARD_FILL_WRONG_OWNER
            );

            emit BackwardSwapFilled(
                swapTxHash,
                fromTokenAddr,
                recipient,
                fromChainId,
                tokenId
            );

            return;
        }

        revert(ERR721_FILL_NO_PAIR);
    }
}
