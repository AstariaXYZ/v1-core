pragma solidity ^0.8.17;

import {LenderEnforcer} from "starport-core/enforcers/LenderEnforcer.sol";
import {AdditionalTransfer} from "starport-core/lib/StarportLib.sol";
import {Starport} from "starport-core/Starport.sol";
import {BasePricing} from "starport-core/pricing/BasePricing.sol";
import {SpentItem} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {AstariaV1Lib} from "src/lib/AstariaV1Lib.sol";

contract AstariaV1LenderEnforcer is LenderEnforcer {
    uint256 constant MAX_DURATION = uint256(3 * 365 * 1 days); // 3 years

    error LoanAmountExceedsCaveatAmount();
    error LoanRateLessThanCaveatRate();
    error DebtBundlesNotSupported();

    //TODO: add strategy for supporting collection offers
    function validate(
        AdditionalTransfer[] calldata additionalTransfers,
        Starport.Loan calldata loan,
        bytes calldata caveatData
    ) public view virtual override {
        if (loan.debt.length > 1) {
            revert DebtBundlesNotSupported();
        }

        uint256 loanRate = abi.decode(loan.terms.pricingData, (BasePricing.Details)).rate;
        uint256 loanAmount = loan.debt[0].amount;
        uint256 recallMax = AstariaV1Lib.getBaseRecallRecallMax(loan.terms.statusData);
        uint256 decimals = AstariaV1Lib.getBasePricingDecimals(loan.terms.pricingData);
        AstariaV1Lib.validateCompoundInterest(loanAmount, loanRate, recallMax, decimals);

        LenderEnforcer.Details memory details = abi.decode(caveatData, (LenderEnforcer.Details));
        SpentItem memory caveatDebt = details.loan.debt[0];

        if (loanAmount > caveatDebt.amount) {
            //Debt amount is greater than the max amount or the caveatDebt amount
            revert LoanAmountExceedsCaveatAmount();
        }

        if (loanRate < AstariaV1Lib.getBasePricingRate(details.loan.terms.pricingData)) {
            //Loan rate is less than the caveatDebt rate
            revert LoanRateLessThanCaveatRate();
        }

        AstariaV1Lib.setBasePricingRate(details.loan.terms.pricingData, loanRate);
        caveatDebt.amount = loanAmount;
        _validate(additionalTransfers, loan, details);
    }
}
