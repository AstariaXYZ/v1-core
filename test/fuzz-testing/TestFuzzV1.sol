pragma solidity ^0.8.17;

import "starport-test/utils/FuzzStructs.sol" as Fuzz;

import {
    SpentItem,
    ItemType,
    CaveatEnforcer,
    StarportTest,
    AdditionalTransfer,
    Pricing,
    BaseFuzzStarport,
    FixedPointMathLib
} from "starport-test/fuzz-testing/BaseFuzzStarport.sol";
import {Starport} from "starport-core/Starport.sol";
import {
    AstariaV1Status,
    AstariaV1Pricing,
    AstariaV1Settlement,
    AstariaV1Test,
    BaseRecall,
    AstariaV1LenderEnforcer,
    BasePricing
} from "test/AstariaV1Test.sol";
import {Validation} from "starport-core/lib/Validation.sol";
import "forge-std/console.sol";

contract TestFuzzV1 is AstariaV1Test, BaseFuzzStarport {
    uint256 public decimals;
    uint256 public rate;

    function setUp() public virtual override (AstariaV1Test, BaseFuzzStarport) {
        super.setUp();
    }

    function _boundStatusData() internal virtual override returns (bytes memory statusData) {
        uint256 maxRecallRate = 10 * 10 ** decimals;

        statusData = abi.encode(
            BaseRecall.Details({
                honeymoon: _boundMax(_random(), 365 days),
                recallWindow: _bound(_random(), 1, 365 days),
                recallMax: rate == maxRecallRate ? rate : _bound(_random(), rate, maxRecallRate)
            })
        );
    }

    function _boundSettlementData() internal virtual override returns (bytes memory settlementData) {
        settlementData = "";
    }

    function _boundPricingData() internal virtual override returns (bytes memory pricingData) {
        decimals = _bound(_random(), 1, 18);
        rate = _bound(_random(), 1, 10 ** (decimals + 1)); // 1000% interest rate

        pricingData = abi.encode(
            BasePricing.Details({rate: rate, carryRate: _boundMax(_random(), 10 ** decimals), decimals: decimals})
        );
    }

    function _boundRefinanceData(Starport.Loan memory loan)
        internal
        virtual
        override
        returns (bytes memory newPricing)
    {
        decimals = abi.decode(loan.terms.pricingData, (BasePricing.Details)).decimals;

        uint256 recallRate = BaseRecall(loan.terms.status).getRecallRate(loan);
        vm.assume(recallRate != 0);

        newPricing = abi.encode(
            BasePricing.Details({rate: recallRate, carryRate: _boundMax(_random(), 10 ** decimals), decimals: decimals})
        );
    }

    function _boundFuzzLoan(FuzzLoan memory params) internal virtual override returns (Starport.Loan memory loan) {
        loan.terms = _boundFuzzLenderTerms();

        vm.assume(params.collateral.length != 0);

        params.collateralLength =
            _bound(params.collateralLength, 1, params.collateral.length < 4 ? params.collateral.length : 4);

        SpentItem[] memory ret = new SpentItem[](params.collateralLength);

        for (uint256 i; i < params.collateralLength; i++) {
            ret[i] = _boundSpentItem(params.collateral[i]);
        }

        loan.collateral = ret;

        SpentItem[] memory debt = new SpentItem[](1);
        debt[0] = SpentItem({
            itemType: ItemType.ERC20,
            identifier: 0,
            amount: _boundMax(params.debtAmount, type(uint112).max),
            token: address(erc20s[1])
        });
        BasePricing.Details memory pDetails = abi.decode(loan.terms.pricingData, (BasePricing.Details));
        while (true) {
            try AstariaV1Pricing(loan.terms.pricing).calculateInterest(
                1, debt[0].amount, pDetails.rate, pDetails.decimals
            ) returns (uint256 interest) {
                break;
            } catch {
                debt[0].amount += 100 ** pDetails.decimals;
                continue;
            }
        }
        loan.debt = debt;
        loan.borrower = borrower.addr;
        loan.custodian = address(custodian);
        loan.issuer = lender.addr;
        return loan;
    }

    function _skipToRepayment(Starport.Loan memory goodLoan) internal virtual override {
        skip(_bound(_random(), 1, uint256(3 * 365 days)));
    }

    function willArithmeticOverflow(Starport.Loan memory loan)
        internal
        view
        virtual
        override
        returns (bool willOverflow)
    {
        vm.assume(AstariaV1Pricing(loan.terms.pricing).validate(loan) == Validation.validate.selector);
        try Pricing(loan.terms.pricing).getPaymentConsideration(loan) returns (
            SpentItem[] memory repayConsideration, SpentItem[] memory carryConsideration
        ) {
            unchecked {
                uint256 newSupply = erc20s[0].totalSupply() + repayConsideration[0].amount;
                if (newSupply < erc20s[0].totalSupply() || newSupply < repayConsideration[0].amount) {
                    return true;
                }
            }
            return false;
        } catch {
            return true;
        }
    }

    //skips to after recall period
    function _skipToSettlement(Starport.Loan memory goodLoan) internal virtual override {
        BaseRecall.Details memory details = abi.decode(goodLoan.terms.statusData, (BaseRecall.Details));
        uint256 delta_t = details.honeymoon + 1;
        skip(delta_t);
        vm.prank(lender.addr);
        BaseRecall(goodLoan.terms.status).recall(goodLoan);
        vm.stopPrank();

        skip(_bound(_random(), details.recallWindow + 1, details.recallWindow + 365 days));
    }

    function _skipToRefinance(Starport.Loan memory goodLoan) internal virtual {
        BaseRecall.Details memory details = abi.decode(goodLoan.terms.statusData, (BaseRecall.Details));
        uint256 delta_t = details.honeymoon + 1;
        skip(delta_t);

        vm.prank(lender.addr);
        BaseRecall(goodLoan.terms.status).recall(goodLoan);

        if (details.recallWindow > 0) {
            skip(_boundMax(_random(), details.recallWindow - 1));
        }
    }

    function _generateGoodLoan(FuzzLoan memory params) internal virtual override returns (Starport.Loan memory) {
        return fuzzNewLoanOrigination(params);
    }

    function _generateSignedCaveatLender(
        Starport.Loan memory loan,
        Account memory signer,
        bytes32 salt,
        bool invalidate
    ) public view virtual override (AstariaV1Test, StarportTest) returns (CaveatEnforcer.SignedCaveats memory) {
        return super._generateSignedCaveatLender(loan, signer, salt, invalidate);
    }

    function _generateSignedCaveatBorrower(Starport.Loan memory loan, Account memory signer, bytes32 salt)
        public
        view
        virtual
        override (AstariaV1Test, StarportTest)
        returns (CaveatEnforcer.SignedCaveats memory)
    {
        return super._generateSignedCaveatBorrower(loan, signer, salt);
    }

    function _generateRefinanceCaveat(
        Account memory account,
        Starport.Loan memory goodLoan,
        bytes memory newPricingDetails,
        address refiFulfiller
    ) internal virtual returns (CaveatEnforcer.SignedCaveats memory signedCaveats) {
        (
            SpentItem[] memory considerationPayment,
            SpentItem[] memory carryPayment,
            AdditionalTransfer[] memory additionalTransfers
        ) = Pricing(goodLoan.terms.pricing).getRefinanceConsideration(goodLoan, newPricingDetails, refiFulfiller);

        assertEq(additionalTransfers.length, 0, "additional transfers not empty");

        Starport.Loan memory refiLoan = loanCopy(goodLoan);
        refiLoan.terms.pricingData = newPricingDetails;
        refiLoan.debt = SP.applyRefinanceConsiderationToLoan(considerationPayment, carryPayment);
        refiLoan.issuer = account.addr;
        refiLoan.originator = address(0);
        refiLoan.start = 0;

        assertEq(address(goodLoan.debt[0].token), address(refiLoan.debt[0].token), "debt tokens not equal");

        _issueAndApproveTarget(refiLoan.debt, account.addr, address(SP));

        vm.assume(!willArithmeticOverflow(refiLoan));

        signedCaveats = refiFulfiller != refiLoan.issuer
            ? super._generateSignedCaveatLender(refiLoan, account, bytes32(msg.sig), true)
            : _emptyCaveat();

        if (refiFulfiller != refiLoan.issuer) {
            uint256 caveatDebt =
                abi.decode(signedCaveats.caveats[0].data, (AstariaV1LenderEnforcer.Details)).loan.debt[0].amount;

            assertEq(caveatDebt, refiLoan.debt[0].amount, "not equal");
        }
    }

    function testFuzzRefinance(FuzzRefinanceLoan memory params) public virtual override {
        Starport.Loan memory goodLoan = _generateGoodLoan(params.origination);

        _skipToRefinance(goodLoan);

        bytes memory newPricingDetails = _boundRefinanceData(goodLoan);
        Account memory account = makeAndAllocateAccount(params.refiKey);

        address refiFulfiller;

        if (params.origination.fulfillerType % 2 == 0) {
            refiFulfiller = goodLoan.borrower;
        } else if (params.origination.fulfillerType % 3 == 0) {
            refiFulfiller = account.addr;
        } else {
            refiFulfiller = _toAddress(_boundMin(_random(), 100));
        }

        {
            CaveatEnforcer.SignedCaveats memory lenderCaveat =
                _generateRefinanceCaveat(account, goodLoan, newPricingDetails, refiFulfiller);

            vm.prank(refiFulfiller);
            SP.refinance(account.addr, lenderCaveat, goodLoan, newPricingDetails, "");
        }
    }
}
