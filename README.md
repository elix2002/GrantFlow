# GrantFlowDAO.clar

Decentralized Research Grant & Milestone Funding DAO  
**Version 2.0 (Refactored & Secured)**

## Overview

GrantFlowDAO is a Clarity smart contract for managing decentralized research grants and milestone-based funding. It enables proposal creation, milestone-based funding, verifier governance, refunds, and secure admin controls.

---

## Features

- **Proposal Creation:**  
  Users can submit proposals with a title, description, funding goal, milestones, and deadline.

- **Funding:**  
  Anyone can fund active proposals. Contributions are tracked per user and proposal.

- **Milestone Approval:**  
  Owner or verifiers can approve milestones, releasing proportional funds to the proposal creator.

- **Refunds:**  
  If a proposal is canceled or fails, contributors can claim refunds.

- **Governance:**  
  Owner can add verifiers to help approve milestones.

- **Admin Controls:**  
  Owner can withdraw funds or transfer ownership.

---

## Contract Structure

- **State Variables:**  
  - `owner`: Contract owner (principal)
  - `proposal-id`: Incremental proposal counter
  - `proposals`: Map of proposals by ID
  - `contributions`: Map of user contributions per proposal
  - `verifiers`: Map of verifier principals

- **Key Public Functions:**  
  - `create-proposal(title, desc, goal, milestones, deadline)`
  - `fund(id, amount)`
  - `approve(id)`
  - `cancel(id)`
  - `refund(id)`
  - `add-verifier(user)`
  - `update-owner(new-owner)`
  - `withdraw(amount, to)`

- **Read-Only Functions:**  
  - `get-proposal(id)`
  - `get-contribution(id, user)`
  - `is-verifier(user)`

---

## Usage

### Proposal Lifecycle

1. **Create Proposal:**  
   Call `create-proposal` with required details.

2. **Fund Proposal:**  
   Call `fund` with proposal ID and amount.

3. **Approve Milestone:**  
   Owner or verifier calls `approve` to release milestone funds.

4. **Cancel Proposal:**  
   Owner or creator can cancel before milestones are completed.

5. **Refund:**  
   Contributors can call `refund` if the proposal is refundable.

### Governance

- **Add Verifier:**  
  Owner calls `add-verifier` with a principal.

- **Change Owner:**  
  Owner calls `update-owner` with a new principal.

- **Withdraw Funds:**  
  Owner calls `withdraw` to transfer contract funds.

---

## Security & Validation

- All external inputs are validated for type and length.
- Only the owner can perform sensitive admin actions.
- All state changes are event-logged for transparency.
- Uses `unwrap!` for safe error handling.

---

## Development

- **Compile & Check:**  
  ```
  clarinet check
  ```

- **Test:**  
  ```
  npm install
  npm test
  ```

---

## License

MIT
