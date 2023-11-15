pragma solidity ^0.8.17;

import "starport-test/StarportTest.sol";

import {BasePricing} from "starport-core/pricing/BasePricing.sol";
import {AstariaV1Pricing} from "src/pricing/AstariaV1Pricing.sol";

import {AstariaV1Status} from "src/status/AstariaV1Status.sol";

import {BaseRecall} from "src/status/BaseRecall.sol";

import {AstariaV1Lib} from "src/lib/AstariaV1Lib.sol";
import {AstariaV1Settlement} from "src/settlement/AstariaV1Settlement.sol";
import {AstariaV1LenderEnforcer} from "src/enforcers/AstariaV1LenderEnforcer.sol";
import {AstariaV1BorrowerEnforcer} from "src/enforcers/AstariaV1BorrowerEnforcer.sol";
import {BorrowerEnforcer} from "starport-core/enforcers/BorrowerEnforcer.sol";
import {CaveatEnforcer} from "starport-core/enforcers/CaveatEnforcer.sol";

contract AstariaV1Test is StarportTest {
    Account recaller;

    function setUp() public virtual override {
        super.setUp();

        recaller = makeAndAllocateAccount("recaller");

        // erc20s[1].mint(recaller.addr, 10000);

        pricing = new AstariaV1Pricing(SP);
        settlement = new AstariaV1Settlement(SP);
        status = new AstariaV1Status(SP);

        lenderEnforcer = new AstariaV1LenderEnforcer();
        borrowerEnforcer = new AstariaV1BorrowerEnforcer();

        vm.startPrank(recaller.addr);
        erc20s[0].approve(address(status), 1e18);
        vm.stopPrank();

        // // 1% interest rate per second
        defaultPricingData = abi.encode(
            BasePricing.Details({carryRate: (uint256(1e16) * 10), rate: (uint256(1e16) * 150), decimals: 18})
        );

        // defaultSettlementData = new bytes(0);

        defaultStatusData = abi.encode(
            BaseRecall.Details({
                honeymoon: 1 days,
                recallWindow: 3 days,
                recallStakeDuration: 30 days,
                // 1000% APR
                recallMax: (uint256(1e16) * 1000),
                // 10%, 0.1
                recallerRewardRatio: uint256(1e16) * 10
            })
        );
    }

    function getRefinanceDetails(Starport.Loan memory loan, bytes memory pricingData, address transactor)
        public
        view
        returns (LenderEnforcer.Details memory)
    {
        (SpentItem[] memory considerationPayment, SpentItem[] memory carryPayment,) =
            Pricing(loan.terms.pricing).getRefinanceConsideration(loan, pricingData, transactor);

        loan = SP.applyRefinanceConsiderationToLoan(loan, considerationPayment, carryPayment, pricingData);
        loan.issuer = transactor;
        loan.start = 0;
        loan.originator = address(0);

        return LenderEnforcer.Details({loan: loan});
    }

    // loan.borrower and signer.addr could be mismatched

    function _generateSignedCaveatBorrower(Starport.Loan memory loan, Account memory signer, bytes32 salt)
        public
        view
        virtual
        override
        returns (CaveatEnforcer.SignedCaveats memory)
    {
        loan = loanCopy(loan);
        loan.issuer = address(0);
        AstariaV1BorrowerEnforcer.V1BorrowerDetails memory v1BorrowerDetails = AstariaV1BorrowerEnforcer
            .V1BorrowerDetails({
            startTime: block.timestamp,
            endTime: block.timestamp,
            startRate: AstariaV1Lib.getBasePricingRate(loan.terms.pricingData),
            minAmount: loan.debt[0].amount,
            maxAmount: loan.debt[0].amount,
            details: BorrowerEnforcer.Details(loan)
        });
        CaveatEnforcer.Caveat memory caveat =
            CaveatEnforcer.Caveat({enforcer: address(borrowerEnforcer), data: abi.encode(v1BorrowerDetails)});
        return signCaveatForAccount(caveat, salt, signer, true);
    }

    // loan.issuer and signer.addr could be mismatched

    function _generateSignedCaveatLender(
        Starport.Loan memory loan,
        Account memory signer,
        bytes32 salt,
        bool invalidate
    ) public view virtual override returns (CaveatEnforcer.SignedCaveats memory) {
        loan = loanCopy(loan);
        loan.borrower = address(0);

        AstariaV1LenderEnforcer.V1LenderDetails memory v1LenderDetails =
            AstariaV1LenderEnforcer.V1LenderDetails({matchIdentifier: true, details: LenderEnforcer.Details(loan)});

        CaveatEnforcer.Caveat memory caveat =
            CaveatEnforcer.Caveat({enforcer: address(lenderEnforcer), data: abi.encode(v1LenderDetails)});

        return signCaveatForAccount(caveat, salt, signer, invalidate);
    }
}
