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
import {CaveatEnforcer} from "starport-core/enforcers/CaveatEnforcer.sol";
import {BasePricing} from "v1-core/pricing/BasePricing.sol";
import {AdditionalTransfer} from "starport-core/lib/StarportLib.sol";

import {AstariaV1Lib} from "v1-core/lib/AstariaV1Lib.sol";

contract AstariaV1BorrowerEnforcer is CaveatEnforcer {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    error AmountExceedsCaveatCollateral();
    error BorrowerOnlyEnforcer();
    error DebtBundlesNotSupported();
    error InvalidLoanTerms();
    error InvalidAdditionalTransfer();
    error LoanAmountOutOfBounds();
    error LoanRateExceedsCurrentRate();
    error StartRateExceedsEndRate();
    error MinAmountExceedsMaxAmount();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STRUCTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    struct Details {
        uint256 startTime;
        uint256 endTime;
        uint256 startRate;
        uint256 maxAmount;
        uint256 minAmount;
        Starport.Loan loan;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     EXTERNAL FUNCTIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Calculates the current maximum valid rate of a caveat
    function locateCurrentRate(bytes calldata caveatData) external view returns (uint256 currentRate) {
        Details memory details = abi.decode(caveatData, (Details));
        return _locateCurrentRate(details);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     PUBLIC FUNCTIONS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Validates a loan against a caveat, w/ an inclining rate auction, and a min/max amount
    /// @dev Bundle support is not implemented, and will revert
    /// @dev The rate in pricing is the endRate.
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

        // Validate the loan amount, rate, and recallMax
        AstariaV1Lib.validateCompoundInterest(
            loanAmount,
            loanRate,
            AstariaV1Lib.getBaseRecallMax(loanTerms.statusData), // recallMax
            AstariaV1Lib.getBasePricingDecimals(loanTerms.pricingData) // decimals
        );

        Details memory details = abi.decode(caveatData, (Details));

        if (details.maxAmount < details.minAmount) {
            revert MinAmountExceedsMaxAmount();
        }

        if (loanAmount < details.minAmount || loanAmount > details.maxAmount) {
            // Debt amount is less than the current caveat amount
            revert LoanAmountOutOfBounds();
        }

        uint256 currentRate = _locateCurrentRate(details);
        if (loanRate > currentRate) {
            // Loan rate is greater than the current caveat rate
            revert LoanRateExceedsCurrentRate();
        }

        // Update the caveat loan rate and amount
        Starport.Loan memory caveatLoan = details.loan;
        uint256 i = 0;
        for (; i < caveatLoan.collateral.length;) {
            if (caveatLoan.collateral[i].amount < loan.collateral[i].amount) {
                revert AmountExceedsCaveatCollateral();
            } else {
                caveatLoan.collateral[i].amount = loan.collateral[i].amount;
            }
            unchecked {
                ++i;
            }
        }
        AstariaV1Lib.setBasePricingRate(caveatLoan.terms.pricingData, loanRate);
        caveatLoan.debt[0].amount = loanAmount;

        // Hash match w/ expected issuer
        _validate(additionalTransfers, loan, caveatLoan);
        selector = CaveatEnforcer.validate.selector;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    INTERNAL FUNCTIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function _locateCurrentRate(Details memory details) internal view returns (uint256 currentRate) {
        uint256 endRate = AstariaV1Lib.getBasePricingRate(details.loan.terms.pricingData);

        if (endRate < details.startRate) {
            revert StartRateExceedsEndRate();
        }
        // if endRate == startRate, or startTime == endTime, or block.timestamp > endTime
        if (endRate == details.startRate || details.startTime == details.endTime || block.timestamp > details.endTime) {
            return endRate;
        }

        // Will revert if startTime > endTime
        uint256 duration = details.endTime - details.startTime;
        uint256 elapsed = block.timestamp - details.startTime;
        uint256 remaining;
        assembly ("memory-safe") {
            // block.timestamp <= endTime, can't underflow
            remaining := sub(duration, elapsed)
        }

        // Calculate rate with a linear growth
        // Weight startRate by the remaining time, and endRate by the elapsed time
        uint256 totalBeforeDivision = (details.startRate * remaining) + (endRate * elapsed);
        assembly ("memory-safe") {
            // duration > 0, as startTime != endTime and endTime - startTime did not underflow
            currentRate := div(totalBeforeDivision, duration)
        }
    }

    function _validate(
        AdditionalTransfer[] calldata additionalTransfers,
        Starport.Loan calldata loan,
        Starport.Loan memory caveatLoan
    ) internal pure {
        caveatLoan.issuer = loan.issuer;
        caveatLoan.originator = loan.originator;
        if (keccak256(abi.encode(loan)) != keccak256(abi.encode(caveatLoan))) revert InvalidLoanTerms();

        if (additionalTransfers.length > 0) {
            uint256 i = 0;
            for (; i < additionalTransfers.length;) {
                if (additionalTransfers[i].from == loan.borrower) revert InvalidAdditionalTransfer();
                unchecked {
                    ++i;
                }
            }
        }
    }
}
