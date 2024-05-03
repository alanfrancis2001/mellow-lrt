// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import "../../interfaces/modules/erc20/IManagedTvlModule.sol";

contract ManagedTvlModule is IManagedTvlModule {
    mapping(address => bytes) public vaultParams;

    function setParams(address vault, Data[] memory data) external {
        IDefaultAccessControl(vault).requireAdmin(msg.sender);
        vaultParams[vault] = abi.encode(data);
    }

    function tvl(address vault) external view returns (Data[] memory data) {
        bytes memory data_ = vaultParams[vault];
        if (data_.length == 0) return data;
        data = abi.decode(data_, (Data[]));
    }
}
