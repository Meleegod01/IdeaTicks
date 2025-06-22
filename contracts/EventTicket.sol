// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC721Royalty, ERC721} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {EventFactory} from "./EventFactory.sol";

error EventTicket__AdminRoleGrantingFailed(bytes32 adminRole, address account);
error EventTicket__BookingPeriodNotOngoing(
    uint256 startingTimestamp,
    uint256 endingTimestamp
);
error EventTicket__AmountExceedsMaxSupply(
    uint256 totalSupply,
    uint256 maxSupply
);
error EventTicket__PurchaseLimitExceeds(
    uint256 purchasingAmount,
    uint256 purchaseLimit
);
error EventTicket__ValueSentNotMatched(
    uint256 valueSent,
    uint256 valueRequired
);
error EventTicket__NothingToWithdraw();
error EventTicket__WithdrawlFailed();

contract EventTicket is ERC721Royalty, AccessControl, ReentrancyGuard {
    bytes32 public constant ORGANIZER_ROLE = keccak256("ORGANIZER_ROLE");

    uint256 private s_ticketCounter;

    uint96 private s_resellLimitBps;
    address private s_organizerAddress;
    uint256 private s_bookingStartTimestamp;
    uint256 private s_bookingEndTimestamp;
    uint256 private s_purchaseLimit;
    mapping(uint256 => EventFactory.Tier) private s_tiers;
    mapping(uint256 => uint256) private s_tokenToTierId;

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(ERC721Royalty, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    constructor(
        string memory _name,
        string memory _symbol,
        EventFactory.Tier[] memory _tiers,
        EventFactory.EventMetadata memory _eventMetadata,
        address _royaltyReceiver,
        address _organizer,
        address _owner
    ) ERC721(_name, _symbol) {
        s_resellLimitBps = _eventMetadata.resellLimitBps;
        s_purchaseLimit = _eventMetadata.purchaseLimit;
        s_bookingStartTimestamp = _eventMetadata.bookingStartTimestamp;
        s_bookingEndTimestamp = _eventMetadata.bookingEndTimestamp;
        s_organizerAddress = _organizer;
        _setDefaultRoyalty(_royaltyReceiver, _eventMetadata.royaltyBps);

        for (uint256 i = 0; i < _tiers.length; i++) {
            s_tiers[_tiers[i].tierId] = _tiers[i];
        }

        bool adminRoleGrantSuccess = _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        if (!adminRoleGrantSuccess)
            revert EventTicket__AdminRoleGrantingFailed(
                DEFAULT_ADMIN_ROLE,
                _owner
            );
        grantRole(ORGANIZER_ROLE, _organizer);
        _setRoleAdmin(ORGANIZER_ROLE, DEFAULT_ADMIN_ROLE);
    }

    function mintTickets(
        uint256 _tierId,
        uint256 _quantity
    ) external payable nonReentrant {
        EventFactory.Tier memory tier = s_tiers[_tierId];
        if (
            block.timestamp < s_bookingStartTimestamp ||
            block.timestamp > s_bookingEndTimestamp
        )
            revert EventTicket__BookingPeriodNotOngoing(
                s_bookingStartTimestamp,
                s_bookingEndTimestamp
            );
        if (tier.mintedAmount + _quantity > tier.maxSupply)
            revert EventTicket__AmountExceedsMaxSupply(
                tier.mintedAmount + _quantity,
                tier.maxSupply
            );
        if (balanceOf(msg.sender) + _quantity > s_purchaseLimit)
            revert EventTicket__PurchaseLimitExceeds(
                balanceOf(msg.sender) + _quantity,
                s_purchaseLimit
            );
        if (msg.value != _quantity * tier.price)
            revert EventTicket__ValueSentNotMatched(
                msg.value,
                _quantity * tier.price
            );

        s_tiers[_tierId].mintedAmount += _quantity;

        for (uint256 i = 0; i < _quantity; i++) {
            uint256 newTicketId = s_ticketCounter;
            s_ticketCounter++;
            _safeMint(msg.sender, newTicketId);
            s_tokenToTierId[newTicketId] = _tierId;
        }
    }

    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        _requireOwned(tokenId);
        string memory baseURI = _baseURI();
        return
            string.concat(baseURI, s_tiers[s_tokenToTierId[tokenId]].ipfsHash);
    }

    function withdrawPrimarySales()
        external
        nonReentrant
        onlyRole(ORGANIZER_ROLE)
    {
        if (address(this).balance == 0) revert EventTicket__NothingToWithdraw();
        (bool success, ) = s_organizerAddress.call{
            value: address(this).balance
        }("");
        if (!success) revert EventTicket__WithdrawlFailed();
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return "ipfs://";
    }
}
