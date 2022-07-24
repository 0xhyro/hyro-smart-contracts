// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import { IOutbox } from "@abacus-network/core/interfaces/IOutbox.sol";
import {IMessageRecipient} from "@abacus-network/core/interfaces/IMessageRecipient.sol";

contract isHumanPoly is IMessageRecipient {
  IOutbox outbox = IOutbox(0x8249cD1275855F2BB20eE71f0B9fA3c9155E5FaB);
  address inbox;
  
  mapping(address => bool) public humans;

  event isHuman(uint32 _origin, bytes32 _sender, bytes _message);
  
  modifier onlyMsgSender(address _user) {
    require(msg.sender == _user);
    _;
  }

  function sendToEth(uint32 _destination, bytes32 _recipient, address _user) external onlyMsgSender(_user) {
    outbox.dispatch(_destination, _recipient, abi.encode(_user));
  }

  function handle (
    uint32 _origin,
    bytes32 _sender,
    bytes memory _message
  ) external override {
    emit isHuman(_origin, _sender, _message);
    (address result) = abi.decode(_message, (address));
    humans[result] = true;
  }
}