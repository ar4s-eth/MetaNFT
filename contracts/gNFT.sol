pragma solidity  ^0.8.0;

import "./ERC3664.sol";

contract gNFT is ERC3664{
  /*string[] public colors;
  mapping(string => bool) _colorExists;

  constructor() ERC721("Color", "COLOR"){
  }

  // E.G. color = "#FFFFFF"
  function mint(string memory _color) public {
    require(!_colorExists[_color]);
    colors.push(_color);
    uint _id = colors.length;
    _mint(msg.sender, _id);
    _colorExists[_color] = true;
  }*/
  
  constructor() ERC3664('Fox', 'Role'){
  }
  
  
}