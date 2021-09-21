// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;



//import "@openzeppelin/contract/token/"


//reference utility: Address, Context, String 
contract ERC3664{

    string private _name;

    string private _symbol;

    struct AttrMetadata{
        string name;
        string symbol;
        uint256 value;
        bool exist;
    }

    //Init attr
    mapping(uint256 => AttrMetadata) private _attrs;

    mapping(uint256 => address) private _owners;

    constructor(string memory name_, string memory symbol_){
        _name = name_;
        _symbol = symbol_;
    }

    //function supportInterface from ERC165

    function ownerOf(uint256 tokenId) public view virtual returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function attrsName(uint256 attrId) public view virtual returns(string memory){
        require(_attrs[attrId].exist == true, 'Cannot get a name on nonexistent attr');
        return _attrs[attrId].name;
    }

    function addAttr(uint256 attrId, string memory name_, string memory symbol_, uint256 value_) public virtual{
        _attrs[attrId].name = name_;
        _attrs[attrId].symbol = symbol_;
        _attrs[attrId].value = value_;
        _attrs[attrId].exist = true;
    }
}