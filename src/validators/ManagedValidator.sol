// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "../interfaces/validators/IManagedValidator.sol";

import "../utils/DefaultAccessControl.sol";

contract ManagedValidator is IManagedValidator {
    uint256 public constant ADMIN_ROLE_MASK = 1 << 255;
    bytes32 public constant STORAGE_POSITION =
        keccak256("mellow.lrt.permissions.storage");

    modifier authorized() {
        requirePermission(msg.sender, address(this), msg.sig);
        _;
    }

    constructor(address admin) {
        Storage storage ds = _storage();
        ds.userRoles[admin] = ADMIN_ROLE_MASK;
    }

    function _storage() internal pure returns (Storage storage ds) {
        bytes32 position = STORAGE_POSITION;

        assembly {
            ds.slot := position
        }
    }

    function hasPermission(
        address user,
        address contractAddress,
        bytes4 signature
    ) public view returns (bool) {
        Storage storage s = _storage();
        uint256 roleSet = s.userRoles[user] | s.publicRoles;
        if ((roleSet & ADMIN_ROLE_MASK) > 0) return true;
        if ((roleSet & s.allowAllSignaturesRoles[contractAddress]) > 0)
            return true;
        if ((roleSet & s.allowSignatureRoles[contractAddress][signature]) > 0)
            return true;
        return false;
    }

    function requirePermission(
        address user,
        address contractAddress,
        bytes4 signature
    ) public view {
        if (!hasPermission(user, contractAddress, signature))
            revert Forbidden();
    }

    function grantPublicRole(uint8 role) external authorized {
        _storage().publicRoles |= 1 << role;
    }

    function revokePublicRole(uint8 role) external authorized {
        _storage().publicRoles &= ~(1 << role);
    }

    function grantRole(address user, uint8 role) external authorized {
        _storage().userRoles[user] |= 1 << role;
    }

    function revokeRole(address user, uint8 role) external authorized {
        _storage().userRoles[user] &= ~(1 << role);
    }

    function setCustomValidator(
        address contractAddress,
        address validator
    ) external authorized {
        if (validator == address(this)) revert Forbidden();
        _storage().customValidator[contractAddress] = validator;
    }

    function grantContractRole(
        address contractAddress,
        uint8 role
    ) external authorized {
        _storage().allowAllSignaturesRoles[contractAddress] |= 1 << role;
    }

    function revokeContractRole(
        address contractAddress,
        uint8 role
    ) external authorized {
        _storage().allowAllSignaturesRoles[contractAddress] &= ~(1 << role);
    }

    function grantContractSignatureRole(
        address contractAddress,
        bytes4 signature,
        uint8 role
    ) external authorized {
        _storage().allowSignatureRoles[contractAddress][signature] |= 1 << role;
    }

    function revokeContractSignatureRole(
        address contractAddress,
        bytes4 signature,
        uint8 role
    ) external authorized {
        _storage().allowSignatureRoles[contractAddress][signature] &= ~(1 <<
            role);
    }

    function customValidator(
        address contractAddress
    ) external view returns (address) {
        return _storage().customValidator[contractAddress];
    }

    function userRoles(address user) external view returns (uint256) {
        return _storage().userRoles[user];
    }

    function publicRoles() external view returns (uint256) {
        return _storage().publicRoles;
    }

    function allowAllSignaturesRoles(
        address contractAddress
    ) external view returns (uint256) {
        return _storage().allowAllSignaturesRoles[contractAddress];
    }

    function allowSignatureRoles(
        address contractAddress,
        bytes4 selector
    ) external view returns (uint256) {
        return _storage().allowSignatureRoles[contractAddress][selector];
    }

    function validate(
        address from,
        address to,
        bytes calldata data
    ) external view {
        if (data.length < 0x4) revert InvalidData();
        requirePermission(from, to, bytes4(data[:4]));
        address validator = _storage().customValidator[to];
        if (validator == address(0)) return;
        IValidator(validator).validate(from, to, data);
    }
}
