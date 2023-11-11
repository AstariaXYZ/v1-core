pragma solidity ^0.8.17;

import {Starport} from "starport-core/Starport.sol";
import {BasePricing} from "starport-core/pricing/BasePricing.sol";
import {BaseRecallPricing} from "./BaseRecallPricing.sol";
import {AstariaV1Lib} from "src/lib/AstariaV1Lib.sol";

abstract contract CompoundInterestPricing is BaseRecallPricing {
    function calculateInterest(uint256 delta_t, uint256 amount, uint256 rate, uint256 decimals)
        public
        pure
        override
        returns (uint256)
    {
        return AstariaV1Lib.calculateCompoundInterest(delta_t, amount, rate, decimals);
    }
}
