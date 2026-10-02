# Security Specification — Wallet by BudgetBakers (Clean Architecture)

## 1. Data Invariants
1. **Strict Tenant Isolation**: Every document inside `/users/{userId}` and its subcollections (`accounts`, `transactions`, `categories`, `budgets`, `summaries`) MUST belong exclusively to `request.auth.uid == userId` AND contain `data.userId == request.auth.uid`.
2. **Master Gate Relational Sync**: Subcollection writes and single-doc reads (`accounts`, `transactions`, `categories`, `budgets`, `summaries`) require that the parent `/users/{userId}` profile document exists (`exists(/databases/$(database)/documents/users/$(userId))`).
3. **Verified Identity**: All writes require `request.auth != null && request.auth.token.email_verified == true`.
4. **Temporal & Ownership Immutability**: `createdAt` and `userId` are set at creation (`createdAt == request.time`) and cannot be mutated during updates (`incoming().createdAt == existing().createdAt && incoming().userId == existing().userId && incoming().updatedAt == request.time`).
5. **Query Enforcer**: All `allow list` operations validate `resource.data.userId == request.auth.uid && request.auth.uid == userId` without calling `get()` or `exists()`.

## 2. The "Dirty Dozen" Payloads
1. **Cross-Tenant Account Read**: User `user_A` attempts `get` on `/users/user_B/accounts/acc_1`. -> `PERMISSION_DENIED`
2. **Spoofed Owner Field**: User `user_A` creates `/users/user_A/accounts/acc_1` with `{"userId": "user_B", ...}`. -> `PERMISSION_DENIED`
3. **Shadow Field Injection**: User `user_A` updates `/users/user_A/accounts/acc_1` adding `"isAdmin": true`. -> `PERMISSION_DENIED`
4. **Unverified Email Write**: User `user_A` with `email_verified: false` creates a transaction. -> `PERMISSION_DENIED`
5. **Orphaned Subcollection Write**: User `user_A` creates `/users/user_A/transactions/tx_1` before `/users/user_A` exists. -> `PERMISSION_DENIED`
6. **Negative Transaction Amount**: User `user_A` creates `/users/user_A/transactions/tx_1` with `amount: -500`. -> `PERMISSION_DENIED`
7. **Forged Timestamp on Create**: User `user_A` sends a past `createdAt` timestamp instead of `request.time`. -> `PERMISSION_DENIED`
8. **Mutating Immutable `createdAt`**: User `user_A` updates a budget and changes `createdAt`. -> `PERMISSION_DENIED`
9. **Oversized String DoW Attack**: User `user_A` injects a 5,000-char string into `note` (max 200). -> `PERMISSION_DENIED`
10. **Invalid Currency Enum**: User `user_A` sets `currency: "BTC"` on an account (only `GTQ`, `USD`, `EUR`, `MXN` allowed). -> `PERMISSION_DENIED`
11. **Malformed `year_month` ID**: User `user_A` creates `/users/user_A/summaries/october-2026` (must match `^[0-9]{4}_[0-9]{2}$`). -> `PERMISSION_DENIED`
12. **Blanket List Scraping**: User `user_A` attempts `list` on `/users/user_B/transactions`. -> `PERMISSION_DENIED`
