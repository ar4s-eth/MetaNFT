// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/access/Ownable.sol";
import "openzeppelin-solidity/contracts/utils/Address.sol";
import "openzeppelin-solidity/contracts/utils/math/Math.sol";
import "openzeppelin-solidity/contracts/utils/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/utils/introspection/IERC1820Registry.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC777/IERC777.sol";
import "openzeppelin-solidity/contracts/token/ERC777/IERC777Recipient.sol";
import "openzeppelin-solidity/contracts/token/ERC1155/IERC1155.sol";
import "openzeppelin-solidity/contracts/token/ERC1155/IERC1155Receiver.sol";

contract NFTBlindBox is IERC777Recipient, IERC1155Receiver, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    bytes4 internal constant ERC1155_RECEIVED_VALUE = 0xf23a6e61;
    bytes4 internal constant ERC1155_BATCH_RECEIVED_VALUE = 0xbc197c81;

    IERC1820Registry private _erc1820 =
        IERC1820Registry(0x88887eD889e776bCBe2f0f9932EcFaBcDfCd1820);
    // keccak256("ERC777TokensRecipient")
    bytes32 private constant TOKENS_RECIPIENT_INTERFACE_HASH =
        0xb281fc8c12954d22544db45de3159a39272895b169a852b314f9cc762e44c53b;

    address public nft;

    address public incubator;
    // drepublic coin
    address public drpc;
    // usdt
    address public usdt;

    struct StageInfo {
        uint256 drpcPrice;
        uint256 usdtPrice;
    }

    struct InviteInfo {
        uint256 count;
    }

    // stageNum => NFTs
    mapping(uint256 => uint256[]) private nftIds;
    // stageNum => stageInfo
    mapping(uint256 => StageInfo) public stages;
    mapping(address => address) public inviter;
    mapping(address => InviteInfo) public userInvited;
    mapping(uint256 => bool) public nftOnSale;

    event LuckyDrawNFT(
        address indexed to,
        uint256 tokenId,
        uint256 value,
        uint256 stageNum
    );
    event BatchUploadNFT(address indexed from, uint256 count);
    event ReturnNFT(address indexed from, uint256 id);
    event BatchReturnNFT(address indexed from, uint256 count);

    modifier onlyIncubator() {
        require(incubator == _msgSender(), "caller is not the incubator");
        _;
    }

    constructor(address _nft, address _usdt) {
        nft = _nft;
        usdt = _usdt;

        //        _erc1820.setInterfaceImplementer(
        //            address(this),
        //            TOKENS_RECIPIENT_INTERFACE_HASH,
        //            address(this)
        //        );
    }

    function getNFTLength(uint256 stageNum) public view returns (uint256) {
        return nftIds[stageNum].length;
    }

    function getNFTList(uint256 stageNum, uint256 begin)
        public
        view
        returns (uint256[] memory)
    {
        require(
            begin >= 0 && begin < nftIds[stageNum].length,
            "NFTBlindBox#getNFTList: NFTsList out of range"
        );
        uint256 range = Math.min(nftIds[stageNum].length, begin.add(100));
        uint256[] memory res = new uint256[](range);
        for (uint256 i = begin; i < range; i++) {
            res[i - begin] = nftIds[stageNum][i];
        }
        return res;
    }

    function setPrices(
        uint256 stageNum,
        uint256 _drpcPrice,
        uint256 _usdtPrice
    ) external onlyOwner {
        StageInfo storage stageInfo = stages[stageNum];
        stageInfo.drpcPrice = _drpcPrice;
        stageInfo.usdtPrice = _usdtPrice;
    }

    function setNFT(address _nft) external onlyOwner {
        nft = _nft;
    }

    function setCurrency(address _drpc) external onlyOwner {
        drpc = _drpc;
    }

    function setIncubator(address _incubator) external onlyOwner {
        incubator = _incubator;
    }

    function uploadNFTs(uint256 stageNum, uint256[] calldata _ids)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < _ids.length; i++) {
            require(
                !nftOnSale[_ids[i]],
                "NFTBlindBox#uploadNfts: nft already on sale"
            );
            nftIds[stageNum].push(_ids[i]);
            nftOnSale[_ids[i]] = true;
        }
        emit BatchUploadNFT(msg.sender, _ids.length);
    }

    // Withdraw EMERGENCY ONLY.
    function emergencyWithdraw(
        address _token,
        address to,
        uint256 _amount
    ) external onlyOwner {
        require(
            to != address(0),
            "NFTBlindBox#emergencyWithdraw: to address is zero"
        );
        IERC20(_token).safeTransfer(to, _amount);
    }

    function _seed(address _user, uint256 _supply)
        internal
        view
        returns (uint256)
    {
        return
            uint256(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            _user,
                            block.number,
                            block.timestamp,
                            block.difficulty
                        )
                    )
                ) % _supply
            );
    }

    function _luckyDraw(uint256 stageNum, address _from)
        internal
        returns (uint256 _tokenId)
    {
        uint256 length = nftIds[stageNum].length;
        require(length > 0, "NFTBlindBox#_luckyDraw: Already sold out");
        uint256 _index = _seed(_from, length);
        _tokenId = nftIds[stageNum][_index];
        nftIds[stageNum][_index] = nftIds[stageNum][length - 1];
        nftIds[stageNum].pop();
        nftOnSale[_tokenId] = false;
        IERC1155(nft).safeTransferFrom(address(this), _from, _tokenId, 1, "");
        emit LuckyDrawNFT(_from, _tokenId, 1, stageNum);
    }

    function _invite(address from, address _inviter)
        internal
        returns (address)
    {
        address reward_to = inviter[from];
        if (reward_to == address(0) && _inviter != address(0)) {
            reward_to = _inviter;
            inviter[from] = reward_to;
            userInvited[reward_to].count++;
        }
        require(
            reward_to != from,
            "NFTBlindBox#_invite: invite can not be self"
        );
        return reward_to;
    }

    function openBox(
        address token,
        uint256 amount,
        uint256 stageNum
    ) external returns (uint256 _tokenId) {
        uint256 count;
        if (token == drpc) {
            uint256 drpcPrice = stages[stageNum].drpcPrice;
            require(
                drpcPrice > 0 && amount >= drpcPrice,
                "NFTBlindBox#openBox: payment amount less than drpc price"
            );
            count = amount.div(drpcPrice);
        } else if (token == usdt) {
            uint256 usdtPrice = stages[stageNum].usdtPrice;
            require(
                usdtPrice > 0 && amount >= usdtPrice,
                "NFTBlindBox#openBox: payment amount less than usdt price"
            );
            count = amount.div(usdtPrice);
        } else {
            revert("NFTBlindBox#openBox: pay token is not correct");
        }
        require(
            count == 1,
            "NFTBlindBox#openBox: limit one purchase at a time"
        );
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        _tokenId = _luckyDraw(stageNum, msg.sender);
    }

    // erc777 receiveToken
    function tokensReceived(
        address operator,
        address from,
        address, /*to*/
        uint256 amount,
        bytes calldata userData,
        bytes calldata /*_operatorData*/
    ) external override {
        if (userData.length != 64) {
            return;
        }
        require(operator == from, "NFTBlindBox#tokensReceived: only wallet");
        uint256 stageNum;
        address _inviter;
        (stageNum, _inviter) = abi.decode(userData, (uint256, address));
        _inviter = _invite(from, _inviter);
        uint256 count;
        if (msg.sender == drpc) {
            uint256 drpcPrice = stages[stageNum].drpcPrice;
            require(
                drpcPrice > 0 && amount >= drpcPrice,
                "NFTBlindBox#tokensReceived: payment amount less than drpc price"
            );
            count = amount.div(drpcPrice);
        } else {
            revert("NFTBlindBox#tokensReceived: pay token is not correct");
        }
        for (uint256 i = 0; i < count; i++) {
            _luckyDraw(stageNum, from);
        }
    }

    function onERC1155Received(
        address _operator,
        address _from,
        uint256 _id,
        uint256, /*_amount*/
        bytes calldata _data
    ) external override returns (bytes4) {
        require(
            msg.sender == nft,
            "NFTBlindBox#onERC1155Received: only receive nft factory"
        );
        if (_operator == incubator) {
            require(
                !nftOnSale[_id],
                "NFTBlindBox#onERC1155Received: nft already on sale"
            );
            uint256 stageNum = abi.decode(_data, (uint256));
            nftIds[stageNum].push(_id);
            nftOnSale[_id] = true;
            _luckyDraw(stageNum + 1, _from);
            emit ReturnNFT(_from, _id);
        }

        return ERC1155_RECEIVED_VALUE;
    }

    function onERC1155BatchReceived(
        address _operator,
        address _from,
        uint256[] calldata _ids,
        uint256[] calldata, /*_amounts*/
        bytes calldata _data
    ) external override returns (bytes4) {
        require(
            msg.sender == nft,
            "NFTBlindBox#onERC1155Received: only receive nft factory"
        );
        if (_operator == incubator) {
            uint256 stageNum = abi.decode(_data, (uint256));
            for (uint256 i = 0; i < _ids.length; i++) {
                require(
                    !nftOnSale[_ids[i]],
                    "NFTBlindBox#onERC1155BatchReceived: nft already on sale"
                );
                nftIds[stageNum].push(_ids[i]);
                nftOnSale[_ids[i]] = true;
                _luckyDraw(stageNum + 1, _from);
            }
            emit BatchReturnNFT(_from, _ids.length);
        }

        return ERC1155_BATCH_RECEIVED_VALUE;
    }

    function supportsInterface(
        bytes4 /*interfaceID*/
    ) external pure override returns (bool) {
        return true;
    }
}
