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

import {Starport, SpentItem} from "starport-core/Starport.sol";
import {BasePricing} from "starport-core/pricing/BasePricing.sol";
import {AdditionalTransfer} from "starport-core/lib/StarportLib.sol";
import {StarportLib} from "starport-core/lib/StarportLib.sol";

import {ItemType} from "seaport-types/src/lib/ConsiderationEnums.sol";
import {ConsiderationInterface} from "seaport-types/src/interfaces/ConsiderationInterface.sol";
import {ERC20} from "solady/src/tokens/ERC20.sol";
import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";

abstract contract BaseRecall {
    using FixedPointMathLib for uint256;
    using {StarportLib.getId} for Starport.Loan;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    event Recalled(uint256 loanId, address recaller, uint256 end);
    event Withdraw(uint256 loanId, address withdrawer);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  CONSTANTS AND IMMUTABLES                  */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    Starport public immutable SP;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STORAGE                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    mapping(uint256 => Recall) public recalls;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    error AdditionalTransferError();
    error InvalidItemType();
    error InvalidStakeType();
    error InvalidWithdraw();
    error LoanDoesNotExist();
    error LoanHasNotBeenRefinanced();
    error RecallAlreadyExists();
    error RecallBeforeHoneymoonExpiry();
    error WithdrawDoesNotExist();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STRUCTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    struct Details {
        // Period at the begininng of a loan in which the loan cannot be recalled
        uint256 honeymoon;
        // Period for which the recall is active
        uint256 recallWindow;
        // Days of interest a recaller must stake
        uint256 recallStakeDuration;
        // Maximum rate of the recall before failure
        uint256 recallMax;
        // Ratio the recaller gets at liquidation (1e18, 100%, 1.0)
        uint256 recallerRewardRatio;
    }

    struct Recall {
        address payable recaller;
        uint64 start;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        CONSTRUCTOR                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    constructor(Starport SP_) {
        SP = SP_;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     EXTERNAL FUNCTIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @dev Gets the recall rate for a loan
     * @param loan The loan to get the recall rate for
     * @return recallRate The recall rate for the loan
     */
    function getRecallRate(Starport.Loan calldata loan) external view returns (uint256) {
        Details memory details = abi.decode(loan.terms.statusData, (Details));
        BasePricing.Details memory pricingDetails = abi.decode(loan.terms.pricingData, (BasePricing.Details));
        uint256 loanId = loan.getId();

        // Calculates the porportion of time elapsed, then multiplies times the max rate
        uint256 baseAdjustment = 10 ** pricingDetails.decimals;
        uint256 ratio = (((block.timestamp - recalls[loanId].start) * baseAdjustment) / details.recallWindow);
        return (details.recallMax * ratio) / baseAdjustment;
    }

    /**
     * @dev Recalls a loan
     * @param loan      The loan to recall
     */
    function recall(Starport.Loan calldata loan) external {
        Details memory details = abi.decode(loan.terms.statusData, (Details));

        if ((loan.start + details.honeymoon) > block.timestamp) {
            revert RecallBeforeHoneymoonExpiry();
        }

        uint256 loanId = loan.getId();
        if (SP.closed(loanId)) {
            revert LoanDoesNotExist();
        }

        if (recalls[loanId].start > 0) {
            revert RecallAlreadyExists();
        }

        AdditionalTransfer[] memory recallConsideration = _generateRecallConsideration(
            msg.sender, loan, 0, details.recallStakeDuration, 0, msg.sender, payable(address(this))
        );
        recalls[loanId] = Recall(payable(msg.sender), uint64(block.timestamp));

        emit Recalled(loanId, msg.sender, block.timestamp + details.recallWindow);

        if (recallConsideration.length > 0) {
            StarportLib.transferAdditionalTransfers(recallConsideration);
        }
    }

    /**
     * @dev Withdraws the recall stake from the contract
     * @param loan      The loan to withdraw the recall stake from
     * @param receiver  The address to receive the recall stake
     */
    function withdraw(Starport.Loan calldata loan, address receiver) external {
        uint256 loanId = loan.getId();

        // Loan has not been refinanced, loan is still active. SP.tokenId changes on refinance
        if (SP.open(loanId)) {
            revert LoanHasNotBeenRefinanced();
        }

        Recall storage recall = recalls[loanId];
        address recaller = recall.recaller;
        // Ensure that a recall exists for the provided tokenId, ensure that the recall
        if (recall.start == 0 || recaller == address(0)) {
            revert WithdrawDoesNotExist();
        }

        recall.recaller = payable(address(0));
        recall.start = 0;

        Details memory details = abi.decode(loan.terms.statusData, (Details));
        AdditionalTransfer[] memory recallConsideration =
            _generateRecallConsideration(recaller, loan, 0, details.recallStakeDuration, 0, address(this), receiver);

        if (recallConsideration.length > 0) {
            _withdrawRecallStake(recallConsideration);
        }

        emit Withdraw(loanId, receiver);
    }

    /**
     * @dev Generates the consideration for a recall
     * @param loan The loan to generate the consideration for
     * @param proportion The proportion of the recall to generate the consideration for
     * @param from The address to transfer the tokens from
     * @param to The address to transfer the tokens to
     * @return consideration The consideration for the recall
     */
    function generateRecallConsideration(Starport.Loan calldata loan, uint256 proportion, address from, address to)
        external
        view
        returns (AdditionalTransfer[] memory consideration)
    {
        Details memory details = abi.decode(loan.terms.statusData, (Details));
        uint256 loanId = loan.getId();
        return _generateRecallConsideration(
            recalls[loanId].recaller, loan, 0, details.recallStakeDuration, proportion, from, to
        );
    }

    function _generateRecallConsideration(
        address recaller,
        Starport.Loan calldata loan,
        uint256 start,
        uint256 end,
        uint256 proportion,
        address from,
        address to
    ) internal pure returns (AdditionalTransfer[] memory additionalTransfers) {
        if (loan.issuer != recaller && loan.borrower != recaller) {
            additionalTransfers = new AdditionalTransfer[](loan.debt.length);

            uint256 delta_t = end - start;
            BasePricing.Details memory details = abi.decode(loan.terms.pricingData, (BasePricing.Details));
            uint256 baseAdjustment = (10 ** details.decimals);
            proportion = baseAdjustment - proportion;
            for (uint256 i; i < additionalTransfers.length;) {
                SpentItem memory debtItem = loan.debt[i];
                uint256 stake = BasePricing(loan.terms.pricing).calculateInterest(
                    delta_t, debtItem.amount, details.rate, details.decimals
                );
                additionalTransfers[i] = AdditionalTransfer({
                    itemType: debtItem.itemType,
                    identifier: debtItem.identifier,
                    amount: (stake * proportion) / baseAdjustment,
                    token: debtItem.token,
                    from: from,
                    to: to
                });
                unchecked {
                    ++i;
                }
            }
        } else {
            additionalTransfers = new AdditionalTransfer[](0);
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    INTERNAL FUNCTIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @dev Withdraws the recall stake from the contract
     * @param transfers The transfers to make
     */
    function _withdrawRecallStake(AdditionalTransfer[] memory transfers) internal {
        uint256 i = 0;
        for (i; i < transfers.length;) {
            AdditionalTransfer memory transfer = transfers[i];
            if (transfer.itemType != ItemType.ERC20) {
                revert InvalidItemType();
            }
            ERC20(transfer.token).transfer(transfer.to, transfer.amount);

            unchecked {
                ++i;
            }
        }
    }
}
