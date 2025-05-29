# ClaimMint Token Marketplace Contract

A Clarity smart contract for managing secure token airdrops and reward distributions on the Stacks blockchain. This contract provides a comprehensive framework for distributing fungible tokens to eligible participants with flexible controls and security measures.

## Features

- **Secure Token Distribution**: Implements SIP-010 fungible token standard compatibility
- **Flexible Reward Management**: Configurable reward amounts and distribution quotas per participant
- **Access Control**: Whitelist-based participant management with admin controls
- **Time-based Programs**: Support for time-limited distribution campaigns
- **Emergency Controls**: Administrative functions for program suspension and token recovery
- **Comprehensive Validation**: Built-in checks for amounts, participants, and program status

## Contract Architecture

### Core Components

- **Token Management**: Handles SIP-010 compliant token registration and verification
- **Participant Registry**: Maintains whitelist of eligible recipients and their quotas
- **Distribution Ledger**: Tracks claimed rewards per participant
- **Program Controls**: Manages program lifecycle, timing, and status

### Key Constants

- `VR-DISTRIBUTION-CEILING`: Maximum distributable amount (1,000,000,000)
- `VR-MINIMUM-REWARD`: Minimum reward amount (1)
- `VR-DURATION-MAXIMUM`: Maximum program duration (10,000 blocks)

## Usage Guide

### For Administrators

#### 1. Initialize the Program
```clarity
(vr-initialize-program total-tokens reward-per-claim program-duration)
```
- `total-tokens`: Total tokens available for distribution
- `reward-per-claim`: Amount each participant receives per claim
- `program-duration`: Program duration in blocks

#### 2. Register Token Contract
```clarity
(vr-register-token token-contract)
```
Register and verify the SIP-010 token contract to be distributed.

#### 3. Manage Participants
```clarity
;; Grant access to a participant
(vr-grant-access participant-address)

;; Set individual reward quota
(vr-set-participant-quota participant-address quota-amount)

;; Revoke access if needed
(vr-revoke-access participant-address)
```

#### 4. Program Management
```clarity
;; Suspend program if needed
(vr-suspend-program)

;; Update program expiration
(vr-update-expiration new-end-height)

;; Emergency token withdrawal
(vr-withdraw-tokens token-contract amount)
```

### For Participants

#### Claim Rewards
```clarity
(vr-claim-rewards token-contract)
```
Eligible participants can claim their allocated rewards using this function.

## Read-Only Functions

### Query Functions Available

- `vr-get-participant-rewards`: Check claimed rewards for a participant
- `vr-get-active-token`: Get the currently active token contract
- `vr-is-eligible-participant`: Check if an address is eligible
- `vr-get-program-controller`: Get the program administrator
- `vr-check-whitelist-status`: Check whitelist status
- `vr-get-program-details`: Get comprehensive program information

## Security Features

### Access Control
- Only the program controller can perform administrative functions
- Participants are validated before granting access
- Contract owner and controller are automatically excluded from participation

### Validation Checks
- Amount validation (within min/max bounds)
- Time frame validation (within maximum duration)
- Token contract verification
- Duplicate request prevention
- Sufficient balance checks

### Error Handling
Comprehensive error codes for different failure scenarios:
- `VR-ERR-UNAUTHORIZED` (100): Unauthorized access
- `VR-ERR-DUPLICATE-REQUEST` (101): Duplicate operation
- `VR-ERR-ACCESS-DENIED` (102): Access denied
- `VR-ERR-QUANTITY-ERROR` (103): Invalid quantity
- `VR-ERR-INSUFFICIENT-BALANCE` (104): Insufficient balance
- `VR-ERR-PROGRAM-INACTIVE` (105): Program not active
- `VR-ERR-TOKEN-NOT-SET` (106): No token configured
- `VR-ERR-TOKEN-VERIFICATION-FAILED` (107): Token verification failed
- `VR-ERR-VALUE-OUT-OF-BOUNDS` (108): Value out of bounds
- `VR-ERR-TIME-LIMIT-EXCEEDED` (109): Time limit exceeded
- `VR-ERR-INVALID-RECIPIENT` (110): Invalid recipient

## Deployment Guide

### Prerequisites
- Stacks blockchain development environment
- Clarity CLI or compatible development tools
- SIP-010 compliant token contract to distribute

### Deployment Steps

1. **Deploy the Contract**
   ```bash
   clarinet deploy --network=testnet contracts/claimmint.clar
   ```

2. **Initialize Program**
   - Call `vr-initialize-program` with your parameters
   - Register your token contract using `vr-register-token`

3. **Set Up Participants**
   - Add eligible participants using `vr-grant-access`
   - Set individual quotas using `vr-set-participant-quota`

4. **Fund the Contract**
   - Transfer tokens to the contract address for distribution

### Testing

The contract includes comprehensive validation and can be tested with:
- Unit tests for individual functions
- Integration tests for complete workflows
- Security tests for access control and validation

## Best Practices

### For Administrators
- Always test on testnet before mainnet deployment
- Set reasonable program durations and reward amounts
- Monitor program status and participant activity
- Keep emergency controls accessible for quick response

### For Integration
- Verify token contract compatibility before registration
- Implement proper error handling in client applications
- Monitor block height for time-sensitive operations
- Cache read-only function results to optimize performance
