//SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import './interfaces/IHyroFactory.sol';
import './Hyro.sol';

interface IHuman {
       function humans(address wallet) external view returns(bool); 
}

contract HyroFactory {

    
    address public feeTo;
    address public owner;

    mapping(address => address) public getHyro;
    address[] public allHyros;
    address[] public whitelistedTokens;
    address private humanVerification;

    event HyroCreated(address hyroContract, address hyro, uint);

    constructor(address _owner, address _feeTo, address _humanVerification) {
        owner = _owner;
        feeTo = _feeTo;
        humanVerification = _humanVerification;
    }

    function getWhitelistedTokens() public view returns (address[] memory _whitelistedTokens) {
        _whitelistedTokens = whitelistedTokens;
    }

    function addWhitelistedTokens(address[] memory _tokens) public  {
        for (uint256 i; i < _tokens.length; i++) {
            whitelistedTokens.push(_tokens[i]);
        }
    }

    function allHyrosLength() external view returns (uint) {
        return allHyros.length;
    }

    function createHyro(address hyro) external returns (address hyroContract) {
        require(hyro != address(0), 'Hyro: ZERO_ADDRESS');
        require(getHyro[hyro] == address(0), 'Hyro: HYRO_EXISTS');
        require(IHuman(humanVerification).humans(hyro) == true, "Hyro: YOU ARE NOT A HUMAN");
        bytes memory bytecode = type(Hyro).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(hyro));
        assembly {
            hyroContract := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        Hyro(hyroContract).initialize(hyro);
        getHyro[hyro] = hyroContract;
        allHyros.push(hyroContract);
        emit HyroCreated(hyroContract, hyro, allHyros.length);
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == owner, 'Hyro: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setOwner(address _owner) external {
        require(msg.sender == owner, 'Hyro: FORBIDDEN');
        owner = _owner;
    }
}
