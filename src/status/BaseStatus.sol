// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2023 Astaria Labs

pragma solidity ^0.8.17;

import {Starport} from "starport-core/Starport.sol";
import {Status} from "starport-core/status/Status.sol";

abstract contract BaseStatus is Status {
    /*
        * @dev Returns true if the loan is still active, false otherwise.
        * @param loan The loan to check.
        * @param extraData Additional data to be used in the status check.
        * @return bool True if the loan is still active, false otherwise.
        */
    function isRecalled(Starport.Loan calldata loan) external view virtual returns (bool);
}
