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
import {BorrowerEnforcer} from "starport-core/enforcers/BorrowerEnforcer.sol";
import {BasePricing} from "starport-core/pricing/BasePricing.sol";
import {AdditionalTransfer} from "starport-core/lib/StarportLib.sol";

import {AstariaV1Lib} from "v1-core/lib/AstariaV1Lib.sol";

contract AstariaV1BorrowerEnforcer is BorrowerEnforcer {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    error DebtBundlesNotSupported();
    error LoanAmountOutOfBounds();
    error LoanRateExceedsCurrentRate();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STRUCTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    struct V1BorrowerDetails {
        uint256 startBlock;
        uint256 endBlock;
        uint256 startRate;
        uint256 maxAmount;
        uint256 minAmount;
        BorrowerEnforcer.Details details;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     EXTERNAL FUNCTIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Calculates the current maximum valid rate of a caveat
    function locateCurrentRate(bytes calldata caveatData) external view returns (uint256 currentRate) {
        V1BorrowerDetails memory v1Details = abi.decode(caveatData, (V1BorrowerDetails));
        return _locateCurrentRate(v1Details);
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
    ) public view virtual override {
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
            AstariaV1Lib.getBaseRecallRecallMax(loanTerms.statusData), // recallMax
            AstariaV1Lib.getBasePricingDecimals(loanTerms.pricingData) // decimals
        );

        V1BorrowerDetails memory v1Details = abi.decode(caveatData, (V1BorrowerDetails));

        if (loanAmount < v1Details.minAmount || loanAmount > v1Details.maxAmount) {
            // Debt amount is less than the current caveat amount
            revert LoanAmountOutOfBounds();
        }

        uint256 currentRate = _locateCurrentRate(v1Details);
        if (loanRate > currentRate) {
            // Loan rate is greater than the current caveat rate
            revert LoanRateExceedsCurrentRate();
        }

        // Update the caveat loan rate and amount
        Starport.Loan memory caveatLoan = v1Details.details.loan;
        AstariaV1Lib.setBasePricingRate(caveatLoan.terms.pricingData, loanRate);
        caveatLoan.debt[0].amount = loanAmount;

        // Hash match w/ expected issuer
        _validate(additionalTransfers, loan, v1Details.details);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    INTERNAL FUNCTIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function _locateCurrentRate(V1BorrowerDetails memory v1Details) internal view returns (uint256 currentRate) {
        uint256 endRate = AstariaV1Lib.getBasePricingRate(v1Details.details.loan.terms.pricingData);

        // if endRate == startRate, or startBlock == endBlock, or block.number > endBlock
        if (
            endRate == v1Details.startRate || v1Details.startBlock == v1Details.endBlock
                || block.number > v1Details.endBlock
        ) {
            return endRate;
        }

        // Will revert if startBlock > endBlock
        uint256 duration = v1Details.endBlock - v1Details.startBlock;
        uint256 elapsed;
        uint256 remaining;
        unchecked {
            // block.number <= endBlock && startBlock < endBlock, can't overflow
            elapsed = block.number - v1Details.startBlock;
            // block.number <= endBlock, can't underflow
            remaining = duration - elapsed;
        }

        // Calculate rate with a linear growth
        // Weight startRate by the remaining time, and endRate by the elapsed time
        uint256 totalBeforeDivision = (v1Details.startRate * remaining) + (endRate * elapsed);
        assembly ("memory-safe") {
            currentRate := div(totalBeforeDivision, duration)
        }
    }
}
