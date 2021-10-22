// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721MetadataUpgradeable.sol";

contract ERC721SwapAgent is Initializable, OwnableUpgradeable {
    mapping(string => mapping(address => bool)) public registeredERC721;
    mapping(string => mapping(bytes32 => bool)) public filledERC721Tx;

    event SwapPairRegister(
        address indexed sponsor,
        address indexed erc721Addr,
        string name,
        string symbol
    );
    event SwapStarted(
        address indexed erc721Addr,
        address indexed fromAddr,
        uint256 amount,
        uint256 feeAmount
    );
    event SwapFilled(
        address indexed erc721Addr,
        bytes32 indexed txHash,
        address indexed toAddress,
        uint256 amount
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Ownable_init();
    }

    function registerSwapPair(address erc721Addr, string calldata chain) external {
        require(isChainSupport(chain), "ERC721SwapAgent::registerSwapPair:: chain is not supported");
        require(!registeredERC721[chain][erc721Addr], "ERC721SwapAgent::registerSwapPair:: token is already registered");
        IERC721MetadataUpgradeable meta = IERC721MetadataUpgradeable(erc721Addr);

        string memory name = meta.name();
        string memory symbol = meta.symbol();

        require(bytes(name).length > 0, "ERC721SwapAgent::registerSwapPair:: empty token name");
        require(bytes(symbol).length > 0, "ERC721SwapAgent::registerSwapPair:: empty token symbol");

        registeredERC721[chain][erc721Addr] = true;

        emit SwapPairRegister(msg.sender, erc721Addr, name, symbol);
    }

    function isChainSupport(string memory chain) public pure returns (bool) {
        bytes32 bsc = keccak256(abi.encodePacked("BSC"));
        bytes32 eth = keccak256(abi.encodePacked("ETH"));
        bytes32 target = keccak256(abi.encodePacked(chain));

        if (bsc == target) {
            return true;
        } else if (eth == target) {
            return true;
        }

        return false;
    }
}
