
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

