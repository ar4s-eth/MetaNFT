// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ERC1155/ERC1155Preset.sol";
import "./ERC3664/IERC3664.sol";
import "openzeppelin-solidity/contracts/utils/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC1155/extensions/ERC1155Pausable.sol";

/**
 * @title NFTFactory
 * NFTFactory - ERC1155 contract has create and mint functionality, and supports useful standards from OpenZeppelin,
  like _exists(), name(), symbol(), and totalSupply()
 */
contract NFTFactory is ERC1155Preset {
    using SafeMath for uint256;

    uint256 private _currentNFTId = 0;

    mapping(uint256 => string) public tokenMetadatas;
    mapping(address => uint256[]) private _holderTokens;
    mapping(uint256 => address) public tokenOwners;
    mapping(uint16 => address) public attributes;

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _uri
    ) ERC1155Preset(_name, _symbol, _uri) {}

    function registerAttribute(uint16 _class, address _attr) public onlyOwner {
        attributes[_class] = _attr;
    }

    function getNextTokenID() public view returns (uint256) {
        return _currentNFTId.add(1);
    }

    function getHolderTokens(
        address holder,
        uint256 size,
        uint256 page
    ) public view returns (uint256[] memory) {
        uint256 beginIdx = size * page;
        uint256 rest = _holderTokens[holder].length - beginIdx;
        uint256 quantity = rest > size ? size : rest;
        uint256[] memory tokens = new uint256[](quantity);
        if (quantity > 0) {
            uint256 i = 0;
            while (i < quantity) {
                tokens[i] = _holderTokens[holder][beginIdx + i];
                i++;
            }
        }
        return tokens;
    }

    function holderTokensCount(address holder) public view returns (uint256) {
        return _holderTokens[holder].length;
    }

    function uri(uint256 _id) public view override returns (string memory) {
        require(_exists(_id), "NFTFactory#uri: nonexistent token");
        // We have to convert string to bytes to check for existence
        bytes memory customUriBytes = bytes(customUri[_id]);
        if (customUriBytes.length > 0) {
            return customUri[_id];
        } else {
            return
                string(abi.encodePacked(super.uri(_id), tokenMetadatas[_id]));
        }
    }

    function createNFT(
        address _initialOwner,
        string memory _metadata,
        uint256[] calldata _attributes,
        uint256[] calldata _values,
        bytes[] calldata _texts
    ) public onlyOwner returns (uint256 tokenId) {
        require(
            _attributes.length == _values.length,
            "NFTFactory#createNFT: attributes and values length mismatch"
        );
        // create nft only attach generic attribute.
        uint16 attrType = 2;
        require(
            attributes[attrType] != address(0),
            "NFTFactory#createNFT: invalid attribute type"
        );

        uint256 _id = _currentNFTId++;
        tokenMetadatas[_id] = _metadata;

        IERC3664(attributes[attrType]).batchAttach(
            _id,
            _attributes,
            _values,
            _texts
        );

        tokenId = create(_initialOwner, _id, 1, "", "");
    }

    function batchCreateNFT(
        address[] calldata _initialOwners,
        string[] calldata _metadatas,
        uint256[] calldata _attributes,
        uint256[][] calldata _values,
        bytes[][] calldata _texts
    ) external onlyOwner returns (uint256[] memory tokenIds) {
        require(
            _initialOwners.length == _metadatas.length,
            "NFTFactory#batchCreateNFT: initialOwners and metadatas length mismatch"
        );
        require(
            _initialOwners.length == _values.length,
            "NFTFactory#batchCreateNFT: initialOwners and values length mismatch"
        );
        require(
            attributes[2] != address(0),
            "NFTFactory#createNFT: invalid attribute type"
        );

        tokenIds = new uint256[](_initialOwners.length);
        for (uint256 i = 0; i < _initialOwners.length; i++) {
            createNFT(
                _initialOwners[i],
                _metadatas[i],
                _attributes,
                _values[i],
                _texts[i]
            );
        }
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override(ERC1155Pausable) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; i++) {
            tokenOwners[ids[i]] = to;
            if (from != address(0)) {
                _removeByValue(_holderTokens[from], ids[i]);
            }
            if (to != address(0)) {
                _holderTokens[to].push(ids[i]);
            }
        }
    }

    function _removeByValue(uint256[] storage values, uint256 value) internal {
        uint256 i = 0;
        while (values[i] != value) {
            i++;
        }
        delete values[i];
    }
}
