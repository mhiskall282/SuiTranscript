#[test_only]
module transcript_registry::transcript_tests;

use 0x0::transcript_registry;
use sui::tx_context;
use std::option;

#[test]
fun test_verify_and_revoke() {
    let ctx = &mut tx_context::dummy();
    let owner = @0x1;
    let walrus_cid = x"01";
    let transcript_hash = x"deadbeef";
    let seal = x"00";
    let expiration = option::none();

    // Use the test-only helper in the module to build a Transcript value.
    let mut transcript = transcript_registry::create_test_transcript(
        owner,
        walrus_cid,
        transcript_hash,
        seal,
        expiration,
        ctx,
    );

    // The stored hash should match the provided hash
    assert!(transcript_registry::verify_hash(&transcript, &transcript_hash), 1);

    // Initially the transcript is valid
    assert!(transcript_registry::is_valid(&transcript), 2);

    // Revoke the transcript (sender(ctx) for dummy() is @0x0, matching issuer)
    transcript_registry::revoke_transcript(&mut transcript, ctx);

    // After revocation the transcript should be invalid
    assert!(!transcript_registry::is_valid(&transcript), 3);

    // Consume the transcript before returning (no `drop` ability): transfer it back to owner.
    sui::transfer::public_transfer(transcript, owner);
}
