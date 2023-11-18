// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2023 Astaria Labs

pragma solidity ^0.8.17;

import {Starport} from "starport-core/Starport.sol";

import {BaseRecallPricing} from "v1-core/pricing/BaseRecallPricing.sol";
import {AstariaV1Lib} from "v1-core/lib/AstariaV1Lib.sol";

abstract contract CompoundInterestPricing is BaseRecallPricing {
    // @inheritdoc BasePricing
    function calculateInterest(uint256 delta_t, uint256 amount, uint256 rate, uint256 decimals)
        public
        pure
        override
        returns (uint256)
    {
        return AstariaV1Lib.calculateCompoundInterest(delta_t, amount, rate, decimals);
    }
}
