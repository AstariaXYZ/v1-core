// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2023 Astaria Labs

pragma solidity ^0.8.17;

import {Starport} from "starport-core/Starport.sol";
import {StarportLib} from "starport-core/lib/StarportLib.sol";

import {BaseRecall} from "v1-core/status/BaseRecall.sol";
import {BaseStatus} from "v1-core/status/BaseStatus.sol";

contract AstariaV1Status is BaseStatus, BaseRecall {
    using {StarportLib.getId} for Starport.Loan;

    constructor(Starport SP_) BaseRecall(SP_) {}

    function isActive(Starport.Loan calldata loan, bytes calldata) external view override returns (bool) {
        Details memory details = abi.decode(loan.terms.statusData, (Details));
        uint256 tokenId = loan.getId();
        uint64 start = recalls[tokenId].start;
        return !(start > 0 && start + details.recallWindow < block.timestamp);
    }

    function isRecalled(Starport.Loan calldata loan) external view override returns (bool) {
        Details memory details = abi.decode(loan.terms.statusData, (Details));
        uint256 tokenId = loan.getId();
        uint64 start = recalls[tokenId].start;
        return (start + details.recallWindow > block.timestamp) && start != 0;
    }
}
