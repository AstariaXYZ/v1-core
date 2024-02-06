//  SPDX-License-Identifier: Apache-2.0
//   █████╗ ███████╗████████╗ █████╗ ██████╗ ██╗ █████╗     ██╗   ██╗ ██╗
//  ██╔══██╗██╔════╝╚══██╔══╝██╔══██╗██╔══██╗██║██╔══██╗    ██║   ██║███║
//  ███████║███████╗   ██║   ███████║██████╔╝██║███████║    ██║   ██║╚██║
//  ██╔══██║╚════██║   ██║   ██╔══██║██╔══██╗██║██╔══██║    ╚██╗ ██╔╝ ██║
//  ██║  ██║███████║   ██║   ██║  ██║██║  ██║██║██║  ██║     ╚████╔╝  ██║
//  ╚═╝  ╚═╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═╝      ╚═══╝   ╚═╝
//
//  Astaria v1 Lending
//  Built on Starport https://github.com/astariaXYZ/starport
//  Designed with love by Astaria Labs, Inc

pragma solidity ^0.8.17;

import {Starport} from "starport-core/Starport.sol";
import {Pricing} from "starport-core/pricing/Pricing.sol";
import {BasePricing} from "v1-core/pricing/BasePricing.sol";
import {StarportLib, AdditionalTransfer} from "starport-core/lib/StarportLib.sol";
import {BasePricing} from "v1-core/pricing/BasePricing.sol";
import {Validation} from "starport-core/lib/Validation.sol";

import {AstariaV1Status} from "v1-core/status/AstariaV1Status.sol";
import {AstariaV1Lib} from "v1-core/lib/AstariaV1Lib.sol";

import {SpentItem} from "seaport-types/src/lib/ConsiderationStructs.sol";

contract AstariaV1Pricing is BasePricing {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    error InsufficientRefinance();
    error LoanIsNotRecalled();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        CONSTRUCTOR                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    constructor(Starport SP_) Pricing(SP_) {}

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     EXTERNAL FUNCTIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // @inheritdoc Pricing
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
        Details memory newDetails = abi.decode(newPricingData, (Details));
        Details memory oldDetails = abi.decode(loan.terms.pricingData, (Details));
        if (newDetails.decimals != oldDetails.decimals || newDetails.rate == 0) {
            revert InvalidRefinance();
        }
        // Borrowers can refinance a loan at any time
        if (fulfiller != loan.borrower) {
            // Check if a recall is occurring
            AstariaV1Status status = AstariaV1Status(loan.terms.status);

            if (!status.isRecalled(loan)) {
                revert LoanIsNotRecalled();
            }
            uint256 rate = status.getRecallRate(loan);
            // Offered loan did not meet the terms of the recall auction
            if (newDetails.rate > rate) {
                revert InsufficientRefinance();
            }
        }

        (repayConsideration, carryConsideration) = getPaymentConsideration(loan);
    }

    // @inheritdoc Validation
    function validate(Starport.Loan calldata loan) external view virtual override returns (bytes4 selector) {
        if (msg.sender == address(this)) {
            uint256 loanRate = abi.decode(loan.terms.pricingData, (BasePricing.Details)).rate;
            uint256 loanAmount = loan.debt[0].amount;
            uint256 recallMax = AstariaV1Lib.getBaseRecallMax(loan.terms.statusData);
            uint256 decimals = AstariaV1Lib.getBasePricingDecimals(loan.terms.pricingData);

            AstariaV1Lib.validateCompoundInterest(loanAmount, loanRate, recallMax, decimals);
        } else {
            try Validation(address(this)).validate(loan) {
                selector = Validation.validate.selector;
            } catch {
                selector = bytes4(0xFFFFFFFF);
            }
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     PUBLIC FUNCTIONS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

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
