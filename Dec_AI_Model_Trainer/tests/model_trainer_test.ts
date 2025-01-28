
import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v0.14.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';


// User Registration Tests
Clarinet.test({
    name: "Ensure that users can register successfully",
    async fn(chain: Chain, accounts: Map<string, Account>)
    {
        const deployer = accounts.get("deployer")!;
        const user1 = accounts.get("wallet_1")!;

        let block = chain.mineBlock([
            Tx.contractCall("model_trainer", "register-user", [], user1.address)
        ]);

        // Assert successful registration
        assertEquals(block.receipts[0].result, '(ok true)');

        // Try registering same user again - should fail
        block = chain.mineBlock([
            Tx.contractCall("model_trainer", "register-user", [], user1.address)
        ]);

        assertEquals(block.receipts[0].result, '(err u102)');
    },
});

// Compute Contribution Tests
Clarinet.test({
    name: "Ensure that compute contributions work correctly",
    async fn(chain: Chain, accounts: Map<string, Account>)
    {
        const user1 = accounts.get("wallet_1")!;

        // First register the user
        let block = chain.mineBlock([
            Tx.contractCall("model_trainer", "register-user", [], user1.address)
        ]);

        // Contribute compute power
        block = chain.mineBlock([
            Tx.contractCall("model_trainer", "contribute-compute",
                [types.uint(150)], // More than minimum contribution (100)
                user1.address
            )
        ]);

        assertEquals(block.receipts[0].result, '(ok true)');

        // Try contributing below minimum
        block = chain.mineBlock([
            Tx.contractCall("model_trainer", "contribute-compute",
                [types.uint(50)], // Below minimum contribution
                user1.address
            )
        ]);

        assertEquals(block.receipts[0].result, '(err u103)'); // err-invalid-amount
    },
});

// Staking Tests
Clarinet.test({
    name: "Ensure that token staking mechanism works properly",
    async fn(chain: Chain, accounts: Map<string, Account>)
    {
        const deployer = accounts.get("deployer")!;
        const user1 = accounts.get("wallet_1")!;

        // Register user
        let block = chain.mineBlock([
            Tx.contractCall("model_trainer", "register-user", [], user1.address)
        ]);

        // Stake tokens - minimum stake is 1000
        block = chain.mineBlock([
            Tx.contractCall("model_trainer", "stake-tokens",
                [types.uint(1500)],
                user1.address
            )
        ]);

        assertEquals(block.receipts[0].result, '(ok true)');

        // Try staking below minimum
        block = chain.mineBlock([
            Tx.contractCall("model_trainer", "stake-tokens",
                [types.uint(500)],
                user1.address
            )
        ]);

        assertEquals(block.receipts[0].result, '(err u105)'); // err-insufficient-stake
    },
});

// Reward Claims Tests
Clarinet.test({
    name: "Ensure that reward claims work correctly",
    async fn(chain: Chain, accounts: Map<string, Account>)
    {
        const user1 = accounts.get("wallet_1")!;

        // Setup: Register and contribute
        let block = chain.mineBlock([
            Tx.contractCall("model_trainer", "register-user", [], user1.address),
            Tx.contractCall("model_trainer", "contribute-compute",
                [types.uint(200)],
                user1.address
            )
        ]);

        // Claim rewards
        block = chain.mineBlock([
            Tx.contractCall("model_trainer", "claim-rewards", [], user1.address)
        ]);

        // Should return ok with some reward amount
        assertEquals(block.receipts[0].result.startsWith('(ok u'), true);
    },
});

// Admin Functions Tests
Clarinet.test({
    name: "Ensure that admin functions are protected and work correctly",
    async fn(chain: Chain, accounts: Map<string, Account>)
    {
        const deployer = accounts.get("deployer")!;
        const user1 = accounts.get("wallet_1")!;

        // Update platform parameters as deployer
        let block = chain.mineBlock([
            Tx.contractCall("model_trainer", "update-platform-params",
                [types.uint(200), types.uint(2000), types.uint(10)],
                deployer.address
            )
        ]);

        assertEquals(block.receipts[0].result, '(ok true)');

        // Try updating as non-owner
        block = chain.mineBlock([
            Tx.contractCall("model_trainer", "update-platform-params",
                [types.uint(200), types.uint(2000), types.uint(10)],
                user1.address
            )
        ]);

        assertEquals(block.receipts[0].result, '(err u100)'); // err-owner-only
    },
});

// Reputation System Tests
Clarinet.test({
    name: "Ensure that reputation system works correctly",
    async fn(chain: Chain, accounts: Map<string, Account>)
    {
        const deployer = accounts.get("deployer")!;
        const user1 = accounts.get("wallet_1")!;

        // Register user
        let block = chain.mineBlock([
            Tx.contractCall("ai-training-platform", "register-user", [], user1.address)
        ]);

        // Update reputation as owner
        block = chain.mineBlock([
            Tx.contractCall("ai-training-platform", "update-reputation",
                [types.principal(user1.address), types.uint(50)],
                deployer.address
            )
        ]);

        assertEquals(block.receipts[0].result, '(ok true)');

        // Try updating reputation as non-owner
        block = chain.mineBlock([
            Tx.contractCall("ai-training-platform", "update-reputation",
                [types.principal(user1.address), types.uint(50)],
                user1.address
            )
        ]);

        assertEquals(block.receipts[0].result, '(err u100)'); // err-owner-only
    },
});

