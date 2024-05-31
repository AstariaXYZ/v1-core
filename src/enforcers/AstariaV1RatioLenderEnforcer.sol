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
import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";

contract AstariaV1RatioLenderEnforcer is CaveatEnforcer {
    using FixedPointMathLib for uint256;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    error InvalidLoanTerms();
    error InvalidAdditionalTransfer();
    error LoanRateLessThanCaveatRate();
    error DebtBundlesNotSupported();
    error CollateralBundlesNotSupported();
    error DebtAmountExceedsDebtMax(uint256 maxDebt, uint256 debtAmount);
    error BelowMinCollateralAmount();
    error MaxDebtOrCollateralToDebtRatioZero();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STRUCTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    struct Details {
        bool matchIdentifier;
        uint256 minCollateralAmount;
        uint256 collateralToDebtRatio; // WAD
        Starport.Loan loan;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     PUBLIC FUNCTIONS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Validates a loan against a caveat, w/ a minCollateralAmount, collateralToDebtRatio, and a matchIdentifier
    /// @dev collateralToDebtRatio is a 1e18 value allowing a ratio conversion from collateral to debt, 1e18 was used to allow flexibility on the collateral units lower bound
    /// @dev Collateral bundle support is not implemented, and will revert
    /// @dev Debt bundle support is not implemented, and will revert
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

        if (loan.collateral.length > 1) {
            revert CollateralBundlesNotSupported();
        }

        Starport.Terms calldata loanTerms = loan.terms;
        uint256 loanRate = abi.decode(loanTerms.pricingData, (BasePricing.Details)).rate;
        uint256 debtAmount = loan.debt[0].amount;
        AstariaV1Lib.validateCompoundInterest(
            debtAmount,
            loanRate,
            AstariaV1Lib.getBaseRecallMax(loanTerms.statusData),
            AstariaV1Lib.getBasePricingDecimals(loanTerms.pricingData)
        );

        Details memory details = abi.decode(caveatData, (Details));

        uint256 collateralAmount = loan.collateral[0].amount;
        if (details.minCollateralAmount > collateralAmount) {
            revert BelowMinCollateralAmount();
        }

        uint256 maxDebt = collateralAmount.mulWad(details.collateralToDebtRatio);
        if (debtAmount > maxDebt) {
            revert DebtAmountExceedsDebtMax(maxDebt, debtAmount);
        }

        if (maxDebt == 0) {
            revert MaxDebtOrCollateralToDebtRatioZero();
        }

        bytes memory caveatPricingData = details.loan.terms.pricingData;
        if (loanRate < AstariaV1Lib.getBasePricingRate(caveatPricingData)) {
            // Loan rate is less than the caveatDebt rate
            revert LoanRateLessThanCaveatRate();
        }

        // Update the caveat loan rate
        AstariaV1Lib.setBasePricingRate(caveatPricingData, loanRate);
        Starport.Loan memory caveatLoan = details.loan;

        if (!details.matchIdentifier) {
            // Update the caveat loan identifier
            caveatLoan.collateral[0].identifier = loan.collateral[0].identifier;
        }

        // Update the caveat debt and collateral amounts
        caveatLoan.debt[0].amount = debtAmount;
        caveatLoan.collateral[0].amount = collateralAmount;

        // Hash and match w/ expected borrower and originator
        _validate(additionalTransfers, loan, caveatLoan);
        selector = CaveatEnforcer.validate.selector;
    }

    function _validate(
        AdditionalTransfer[] calldata additionalTransfers,
        Starport.Loan calldata loan,
        Starport.Loan memory caveatLoan
    ) internal pure {
        caveatLoan.borrower = loan.borrower;
        caveatLoan.originator = loan.originator;

        if (keccak256(abi.encode(loan)) != keccak256(abi.encode(caveatLoan))) {
            revert InvalidLoanTerms();
        }

        if (additionalTransfers.length > 0) {
            uint256 i = 0;
            for (; i < additionalTransfers.length;) {
                if (additionalTransfers[i].from == loan.issuer) revert InvalidAdditionalTransfer();
                unchecked {
                    ++i;
                }
            }
        }
    }
}
