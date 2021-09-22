// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/access/Ownable.sol";
import "openzeppelin-solidity/contracts/token/ERC1155/IERC1155.sol";

contract NFTIncubator is Ownable {
    uint32 public incubatorCoolDown = uint32(15 minutes);

    uint32 public incubatorMatchWait = uint32(4 hours);

    address public nft;

    address public blindBox;

    enum IncubatorType {
        None,
        Private,
        Shared
    }

    struct IncubatorInfo {
        IncubatorType iType;
        address owner;
        address storer;
        uint256[2] seats;
        uint256 matchWaitEndTime;
        uint256 coolDownEndTime;
    }

    mapping(uint256 => IncubatorInfo) public incubators;

    event IncubatorStore(
        address indexed from,
        uint256 incubatorId,
        uint256 tokenId
    );
    event IncubatorBreed(
        address indexed from,
        uint256 incubatorId,
        uint256 first,
        uint256 second
    );

    constructor(address _nft, address _blindBox) {
        nft = _nft;
        blindBox = _blindBox;
    }

    function createSharedIncubators(uint256[] calldata _ids) public onlyOwner {
        for (uint256 i = 0; i < _ids.length; i++) {
            require(
                incubators[_ids[i]].iType == IncubatorType.None,
                "NFTIncubator#createSharedIncubators: incubator already created"
            );
            IncubatorInfo storage incubator = incubators[_ids[i]];
            incubator.iType = IncubatorType.Shared;
        }
    }

    function store(uint256 _incubatorId, uint256 _tokenId) public {
        IncubatorInfo storage incubator = incubators[_incubatorId];
        require(
            incubator.iType != IncubatorType.None,
            "NFTIncubator#store, incubator not exist"
        );
        if (incubator.iType == IncubatorType.Private) {
            require(
                _msgSender() == incubator.owner,
                "NFTIncubator#store, not incubator owner"
            );
        } else {
            require(
                incubator.coolDownEndTime <= block.timestamp,
                "NFTIncubator#store, incubator cooldown period"
            );
        }
        require(
            incubator.seats[0] == 0 ||
                (incubator.seats[0] != 0 &&
                    incubator.matchWaitEndTime <= block.timestamp),
            "NFTIncubator#store, incubator already stored"
        );

        require(
            IERC1155(nft).balanceOf(_msgSender(), _tokenId) > 0,
            "NFTIncubator#store, not dragon owner"
        );
        incubator.matchWaitEndTime = block.timestamp + incubatorMatchWait;
        incubator.seats[0] = _tokenId;
        incubator.storer = _msgSender();

        emit IncubatorStore(_msgSender(), _incubatorId, _tokenId);
    }

    function breed(uint256 _incubatorId, uint256 _tokenId) public {
        IncubatorInfo storage incubator = incubators[_incubatorId];
        require(
            incubator.iType != IncubatorType.None,
            "NFTIncubator#breed, incubator not exist"
        );
        uint256 firstToken = incubator.seats[0];
        require(
            firstToken != 0 && incubator.seats[1] == 0,
            "NFTIncubator#breed, incubator not yet stored"
        );
        require(
            IERC1155(nft).balanceOf(_msgSender(), _tokenId) > 0,
            "NFTIncubator#breed, not dragon owner"
        );
        // TODO 匹配属性 stageNum

        IERC1155(nft).safeTransferFrom(
            incubator.storer,
            blindBox,
            firstToken,
            1,
            abi.encode(uint256(1))
        );
        IERC1155(nft).safeTransferFrom(
            _msgSender(),
            blindBox,
            _tokenId,
            1,
            abi.encode(uint256(1))
        );
        incubator.storer = address(0);
        incubator.seats = [0, 0];
        incubator.matchWaitEndTime = 0;
        if (incubator.iType == IncubatorType.Shared) {
            incubator.coolDownEndTime = block.timestamp + incubatorCoolDown;
        }

        emit IncubatorBreed(_msgSender(), _incubatorId, firstToken, _tokenId);
    }
}
