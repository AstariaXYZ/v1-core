//  SPDX-License-Identifier: BUSL-1.1
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
import {LenderEnforcer, CaveatEnforcer} from "starport-core/enforcers/LenderEnforcer.sol";
import {BasePricing} from "starport-core/pricing/BasePricing.sol";
import {AdditionalTransfer} from "starport-core/lib/StarportLib.sol";

import {AstariaV1Lib} from "v1-core/lib/AstariaV1Lib.sol";

import {SpentItem} from "seaport-types/src/lib/ConsiderationStructs.sol";

contract AstariaV1LenderEnforcer is LenderEnforcer {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    error LoanAmountExceedsCaveatAmount();
    error LoanRateLessThanCaveatRate();
    error DebtBundlesNotSupported();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  CONSTANTS AND IMMUTABLES                  */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    uint256 constant MAX_DURATION = uint256(3 * 365 * 1 days); // 3 years

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STRUCTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    struct V1LenderDetails {
        bool matchIdentifier;
        LenderEnforcer.Details details;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     PUBLIC FUNCTIONS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Validates a loan against a caveat, w/ a minimum rate and a maximum amount
    /// @dev Bundle support is not implemented, and will revert
    /// @dev matchIdentifier = false will allow the loan to have a different identifier than the caveat
    /// @dev Only viable for use w/ AstariaV1Pricing and AstariaV1Status modules
    function validate(
        AdditionalTransfer[] calldata additionalTransfers,
        Starport.Loan calldata loan,
        bytes calldata caveatData
    ) public view virtual override returns (bytes4 selector) {
        if (loan.debt.length > 1) {
            revert DebtBundlesNotSupported();
        }

        Starport.Terms calldata loanTerms = loan.terms;
        uint256 loanRate = abi.decode(loanTerms.pricingData, (BasePricing.Details)).rate;
        uint256 loanAmount = loan.debt[0].amount;
        AstariaV1Lib.validateCompoundInterest(
            loanAmount,
            loanRate,
            AstariaV1Lib.getBaseRecallMax(loanTerms.statusData),
            AstariaV1Lib.getBasePricingDecimals(loanTerms.pricingData)
        );

        V1LenderDetails memory v1Details = abi.decode(caveatData, (V1LenderDetails));
        Starport.Loan memory caveatLoan = v1Details.details.loan;
        SpentItem memory caveatDebt = caveatLoan.debt[0];

        if (loanAmount > caveatDebt.amount) {
            // Debt amount is greater than the max amount or the caveatDebt amount
            revert LoanAmountExceedsCaveatAmount();
        }

        bytes memory caveatPricingData = caveatLoan.terms.pricingData;
        if (loanRate < AstariaV1Lib.getBasePricingRate(caveatPricingData)) {
            // Loan rate is less than the caveatDebt rate
            revert LoanRateLessThanCaveatRate();
        }

        // Update the caveat loan rate
        AstariaV1Lib.setBasePricingRate(caveatPricingData, loanRate);
        // Update the caveat loan amount
        caveatDebt.amount = loanAmount;

        if (!v1Details.matchIdentifier) {
            // Update the caveat loan identifier
            caveatDebt.identifier = loan.debt[0].identifier;
        }

        // Hash and match w/ expected borrower
        _validate(additionalTransfers, loan, v1Details.details);
        selector = CaveatEnforcer.validate.selector;
    }
}
