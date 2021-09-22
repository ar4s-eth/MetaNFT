// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";
import "openzeppelin-solidity/contracts/security/ReentrancyGuard.sol";
import "openzeppelin-solidity/contracts/utils/Strings.sol";
import "openzeppelin-solidity/contracts/utils/Address.sol";
import "./ERC3664/extensions/ERC3664CrossSynthetic.sol";
import "./Synthetic/ISynthetic721.sol";
import "./utils/Base64.sol";

interface ICustomMetadata {
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

interface ICoreRegistry {
    function verifyIdentity(address token, uint256 tokenId)
        external
        view
        returns (bool);
}

contract Metacore is
    ERC3664CrossSynthetic,
    ERC721Enumerable,
    ReentrancyGuard,
    Ownable
{
    using Strings for uint256;

    uint256 private constant METANAME = 1;

    address payable public treasury =
        payable(0x99F120C4BA7d3621e26429Cba45A6F52b23DFd1F);

    uint256 private _totalSupply = 8000;

    uint256 private _curTokenId;

    address private _customURI;

    address private _registry;

    mapping(address => bool) private _authNFTs;

    constructor() ERC3664CrossSynthetic() ERC721("Metacore", "MTC") Ownable() {
        _authNFTs[address(0x10949E6d7949C68E6F00B7d907131bE78170bd3F)] = true;
        _mint(METANAME, "Metaname", "Metaname", "");
    }

    function getNextTokenID() public view returns (uint256) {
        return _curTokenId + 1;
    }

    function increaseIssue(uint256 supply) public onlyOwner {
        _totalSupply = supply;
    }

    function setCustomMetadata(address uri) public onlyOwner {
        _customURI = uri;
    }

    function setCoreRegistry(address registry) public onlyOwner {
        _registry = registry;
    }

    function setAuthNFTs(address nft, bool enable) public onlyOwner {
        _authNFTs[nft] = enable;
    }

    function claim(string memory name) public payable nonReentrant {
        require(bytes(name).length > 0, "Metacore: invalid name length");
        require(
            getNextTokenID() <= _totalSupply,
            "Metacore: reached the maximum number of claim"
        );

        uint256 amount = msg.value;
        require(amount >= 4 * 10**16, "Payed too low value");
        Address.sendValue(treasury, 4 * 10**16);

        _curTokenId += 1;
        _safeMint(_msgSender(), _curTokenId);
        attach(_curTokenId, METANAME, 1, bytes(name), true);
    }

    function combine(
        uint256 tokenId,
        address subToken,
        uint256 subId
    ) public {
        require(
            ownerOf(tokenId) == _msgSender(),
            "Metacore: caller is not token owner"
        );
        if (_registry != address(0)) {
            require(
                ICoreRegistry(_registry).verifyIdentity(subToken, subId),
                "Metacore: unregister token address;"
            );
        } else {
            require(_authNFTs[subToken], "Metacore: invalid nft address");
        }

        ISynthetic721 sContract = ISynthetic721(subToken);
        require(
            sContract.getApproved(subId) == address(this),
            "Metacore: caller is not sub token owner nor approved"
        );

        sContract.transferFrom(_msgSender(), address(this), subId);
        synthesizedTokens[tokenId].push(
            SynthesizedToken(subToken, msg.sender, subId)
        );
    }

    function separate(uint256 tokenId) public {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "Metacore: caller is not token owner nor approved"
        );

        SynthesizedToken[] storage subs = synthesizedTokens[tokenId];
        require(subs.length > 0, "Metacore: not synthesized token");
        for (uint256 i = 0; i < subs.length; i++) {
            ISynthetic721(subs[i].token).transferFrom(
                address(this),
                subs[i].owner,
                subs[i].id
            );
        }
        delete synthesizedTokens[tokenId];
    }

    function separateOne(uint256 tokenId, uint256 subId) public {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "Metacore: caller is not token owner nor approved"
        );

        uint256 idx = findByValue(synthesizedTokens[tokenId], subId);
        SynthesizedToken storage token = synthesizedTokens[tokenId][idx];
        ISynthetic721(token.token).transferFrom(
            address(this),
            token.owner,
            token.id
        );
        removeAtIndex(synthesizedTokens[tokenId], idx);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        if (_customURI != address(0)) {
            return ICustomMetadata(_customURI).tokenURI(tokenId);
        }
        return coreTokenURI(tokenId);
    }

    function coreTokenURI(uint256 tokenId) public view returns (string memory) {
        string[4] memory parts;
        parts[
            0
        ] = '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350"><style>.base { fill: white; font-family: serif; font-size: 14px; }</style><rect width="100%" height="100%" fill="black" /><text x="10" y="20" class="base">';

        parts[1] = string(
            abi.encodePacked(
                "Metacore #",
                tokenId.toString(),
                '</text><text x="10" y="40" class="base">'
            )
        );

        parts[2] = string(textOf(tokenId, METANAME));

        parts[3] = "</text></svg>";

        string memory output = string(
            abi.encodePacked(parts[0], parts[1], parts[2], parts[3])
        );
        string memory attributes = getAttributes(tokenId);

        if (synthesizedTokens[tokenId].length > 0) {
            attributes = string(
                abi.encodePacked(
                    attributes,
                    ',{"trait_type":"SYNTHETIC","value":"true"}'
                )
            );
        }

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "Metacore #',
                        tokenId.toString(),
                        '", "description": "MetaCore is an identity system which can make all metaverse citizens join into different metaverses by using same MetaCore Identity. The first modular NFT with MetaCore at its core, with arbitrary attributes addition and removal, freely combine and divide each components. Already adapted to multiple metaverse blockchain games. FUTURE IS COMMING", "image": "data:image/svg+xml;base64,',
                        Base64.encode(bytes(output)),
                        '","attributes":[',
                        attributes,
                        "]}"
                    )
                )
            )
        );
        output = string(
            abi.encodePacked("data:application/json;base64,", json)
        );
        return output;
    }

    function getAttributes(uint256 tokenId)
        public
        view
        returns (string memory)
    {
        bytes memory data = "";
        uint256 id = primaryAttributeOf(tokenId);
        if (id > 0) {
            data = abi.encodePacked(
                '{"trait_type":"',
                symbol(id),
                '","value":"',
                textOf(tokenId, id),
                '"}'
            );
        }
        uint256[] memory attrs = attributesOf(tokenId);
        for (uint256 i = 0; i < attrs.length; i++) {
            if (data.length > 0) {
                data = abi.encodePacked(data, ",");
            }
            data = abi.encodePacked(
                data,
                '{"trait_type":"',
                symbol(attrs[i]),
                '","value":"',
                textOf(tokenId, attrs[i]),
                '"}'
            );
        }
        SynthesizedToken[] storage tokens = synthesizedTokens[tokenId];
        for (uint256 i = 0; i < tokens.length; i++) {
            data = abi.encodePacked(
                data,
                ",",
                concatAttribute(
                    ISynthetic721(tokens[i].token).coreName(),
                    tokens[i].id.toString()
                )
            );
        }
        return string(data);
    }

    function concatAttribute(string memory key, string memory value)
        internal
        pure
        returns (bytes memory)
    {
        return
            abi.encodePacked(
                '{"trait_type":"',
                key,
                '","value":"',
                value,
                '"}'
            );
    }

    function findByValue(SynthesizedToken[] storage values, uint256 value)
        internal
        view
        returns (uint256)
    {
        uint256 i = 0;
        while (values[i].id != value) {
            i++;
        }
        return i;
    }

    function removeAtIndex(SynthesizedToken[] storage values, uint256 index)
        internal
    {
        uint256 max = values.length;
        if (index >= max) return;

        if (index == max - 1) {
            values.pop();
            return;
        }

        for (uint256 i = index; i < max - 1; i++) {
            values[i] = values[i + 1];
        }
        values.pop();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC3664, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
