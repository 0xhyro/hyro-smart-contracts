// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import { IOutbox } from "@abacus-network/core/interfaces/IOutbox.sol";
import {IMessageRecipient} from "@abacus-network/core/interfaces/IMessageRecipient.sol";

interface IProofOfHumanity {
  function isRegistered(address _submissionID) external view returns (bool);
}

contract isHumanEth is IMessageRecipient {
  IOutbox outbox = IOutbox(0x2f9DB5616fa3fAd1aB06cB2C906830BA63d135e3);
  address inbox;

  event getAddress(uint32 _origin, bytes32 _sender, bytes _message);

  function sendToPoly(uint32 _destination, bytes32 _recipient, address _user) public {
    bool _isHuman = IProofOfHumanity(0xC5E9dDebb09Cd64DfaCab4011A0D5cEDaf7c9BDb).isRegistered(_user);
    if (_isHuman == true)
      outbox.dispatch(_destination, _recipient, abi.encode(_user));
  }

  function handle (
    uint32 _origin,
    bytes32 _sender,
    bytes memory _message
  ) external override {
    (address _user) = abi.decode(_message, (address)) ;
    sendToPoly(_origin, _sender, _user);
  }
}