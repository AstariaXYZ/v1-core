// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2023 Astaria Labs

pragma solidity ^0.8.17;

import {Starport} from "starport-core/Starport.sol";
import {Status} from "starport-core/status/Status.sol";

abstract contract BaseStatus is Status {
    function isRecalled(Starport.Loan calldata loan) external view virtual returns (bool);
}
