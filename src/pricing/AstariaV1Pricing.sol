// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2023 Astaria Labs

pragma solidity ^0.8.17;

import {Starport} from "starport-core/Starport.sol";

import {Pricing} from "starport-core/pricing/Pricing.sol";
import {BasePricing} from "starport-core/pricing/BasePricing.sol";
import {StarportLib, AdditionalTransfer} from "starport-core/lib/StarportLib.sol";

import {CompoundInterestPricing} from "v1-core/pricing/CompoundInterestPricing.sol";
import {AstariaV1Status} from "v1-core/status/AstariaV1Status.sol";
import {AstariaV1Lib} from "v1-core/lib/AstariaV1Lib.sol";

import {SpentItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";

contract AstariaV1Pricing is CompoundInterestPricing {
    using FixedPointMathLib for uint256;
    using {StarportLib.getId} for Starport.Loan;

    constructor(Starport SP_) Pricing(SP_) {}

    error InsufficientRefinance();

    function getRefinanceConsideration(Starport.Loan calldata loan, bytes calldata newPricingData, address fulfiller)
        external
        view
        virtual
        override
        returns (
            SpentItem[] memory repayConsideration,
            SpentItem[] memory carryConsideration,
            AdditionalTransfer[] memory recallConsideration
        )
    {
        // borrowers can refinance a loan at any time
        if (fulfiller != loan.borrower) {
            // check if a recall is occuring
            AstariaV1Status status = AstariaV1Status(loan.terms.status);

            if (!status.isRecalled(loan)) {
                revert InvalidRefinance();
            }
            Details memory newDetails = abi.decode(newPricingData, (Details));
            uint256 rate = status.getRecallRate(loan);
            // offered loan did not meet the terms of the recall auction
            if (newDetails.rate > rate) {
                revert InsufficientRefinance();
            }

            Details memory oldDetails = abi.decode(loan.terms.pricingData, (Details));

            uint256 proportion;
            address payable receiver = payable(loan.issuer);
            uint256 loanId = loan.getId();
            // scenario where the recaller is not penalized
            // recaller stake is refunded
            if (newDetails.rate > oldDetails.rate) {
                proportion = 0;
                (receiver,) = status.recalls(loanId);
            } else {
                // scenario where the recaller is penalized
                // essentially the old lender and the new lender split the stake of the recaller
                // split is proportional to the difference in rate
                proportion = (oldDetails.rate - newDetails.rate).divWad(oldDetails.rate);
            }
            recallConsideration = status.generateRecallConsideration(loan, proportion, fulfiller, receiver);
        }

        (repayConsideration, carryConsideration) = getPaymentConsideration(loan);
    }

    function validate(Starport.Loan calldata loan) external pure virtual override returns (bytes4) {
        uint256 loanRate = abi.decode(loan.terms.pricingData, (BasePricing.Details)).rate;
        uint256 loanAmount = loan.debt[0].amount;
        uint256 recallMax = AstariaV1Lib.getBaseRecallRecallMax(loan.terms.statusData);
        uint256 decimals = AstariaV1Lib.getBasePricingDecimals(loan.terms.pricingData);

        AstariaV1Lib.validateCompoundInterest(loanAmount, loanRate, recallMax, decimals);
        return Pricing.validate.selector;
    }
}
