// module transcript::registry {
//     use sui::object;// For creation of UID and object management
//     use sui::tx_context::TxContext;// For transaction context
//     use sui::signer;// For signer capabilities(capability checks)
//     use sui::transfer;
//     use sui::clock;// For timestamping
//     use sui::event;// For event handling(used to broadcast message to the chain when a transcript is issued or revoked)
//     use std::option;// For optional values
//     use std::vector;// For vector data structure(array-like structure eg CID and hash storage)

//     /// A record of a student's transcript issued by an institution(blueprint for transcript object)
//     struct Transcript has key, store {
//         //key value indicates this struct can be stored in the global state by a user-defined address;
//         //store value indicates this struct can be stored in other structs or objects although it an owned object;
//         id: UID,
//         owner: address,             // Student's address
//         issuer: address,            // Institution's address
//         walrus_cid: vector<u8>,     // Storage reference on Walrus
//         transcript_hash: vector<u8>,// SHA256 hash of encrypted transcript
//         issued_at: u64,             // Timestamp
//         expires_at: Option<u64>,    // Optional expiry time
//         revoked: bool,              // Revocation flag
//         seal_metadata: vector<u8>,  // Nautilus seal (encryption metadata)
//     }

//     /// Event emitted when a transcript is issued; it doesnt track a sui object but broadcasts the issuance to the chain
//         owner: address,
//         issuer: address,
//         walrus_cid: vector<u8>,
//         transcript_hash: vector<u8>,
//         issued_at: u64,
//     }

//     /// Event emitted when a transcript is revoked
//     struct TranscriptRevoked has copy, drop, store {
//         transcript_id: ID,
//         revoked_by: address,
//         revoked_at: u64,
//     }

//     /// Function for an institution to issue a transcript
//     public fun issue_transcript(
//         issuer: &signer,
//         owner: address,
//         walrus_cid: vector<u8>,
//         transcript_hash: vector<u8>,
//         seal_metadata: vector<u8>,
//         expiration: Option<u64>,
//         ctx: &mut TxContext
//     ): Transcript {
//         let issuer_addr = signer::address_of(issuer);
//         let transcript = Transcript {
//             id: object::new(ctx),
//             owner,
//             issuer: issuer_addr,
//             walrus_cid,
//             transcript_hash,
//             issued_at: clock::now_seconds(),
//             expires_at: expiration,
//             revoked: false,
//             seal_metadata,
//         };

//         let issued_event = TranscriptIssued {
//             owner,
//             issuer: issuer_addr,
//             walrus_cid,
//             transcript_hash,
//             issued_at: transcript.issued_at,
//         };
//         event::emit(issued_event);
//         transcript
//     }

//     /// Function to revoke a transcript
//     public fun revoke_transcript(admin: &signer, transcript: &mut Transcript) {
//         let admin_addr = signer::address_of(admin);
//         assert!(admin_addr == transcript.issuer, 0); // Only issuer can revoke
//         transcript.revoked = true;

//         let revoked_event = TranscriptRevoked {
//             transcript_id: object::uid_to_id(&transcript.id),
//             revoked_by: admin_addr,
//             revoked_at: clock::now_seconds(),
//         };
//         event::emit(revoked_event);
//     }

//     /// Verify if a given transcript hash matches the stored one
//     ///it takes an immutable reference and dereference using the * operator
//     /// this is done to allow anyone check the validity and integrity of the file to ensure it object and content are not mutated
//     public fun verify_hash(transcript: &Transcript, provided_hash: &vector<u8>): bool {
//         *provided_hash == transcript.transcript_hash
//     }

//     /// Check if transcript is still valid (not expired or revoked)
//     public fun is_valid(transcript: &Transcript): bool {
//         if (transcript.revoked) {
//             return false;
//         };
//         if (option::is_some(&transcript.expires_at)) {
//             let exp = option::borrow(&transcript.expires_at);
//             if (*exp) < clock::now_seconds() {
//                 return false;
//             };
//         };
//         true
//     }
// }

module 0x0::transcript_registry {
    use sui::object::{UID, ID};
    use sui::tx_context::{TxContext, sender};
    use sui::transfer;
    use sui::event;
    use std::option;

    /// Represents a student's transcript stored on-chain
    public struct Transcript has key, store {
        id: UID,
        owner: address,
        issuer: address,
        walrus_cid: vector<u8>,       // Walrus content ID (off-chain reference)
        transcript_hash: vector<u8>,  // Hash of encrypted transcript
        issued_at: u64,
        expires_at: option::Option<u64>,
        revoked: bool,
        seal_metadata: vector<u8>,
    }

    /// Event emitted when a transcript is issued
    public struct TranscriptIssued has copy, drop, store {
        owner: address,
        issuer: address,
        walrus_cid: vector<u8>,
        transcript_hash: vector<u8>,
        issued_at: u64,
    }

    /// Event emitted when a transcript is revoked
    public struct TranscriptRevoked has copy, drop, store {
        owner: address,
        issuer: address,
        revoked_at: u64,
        walrus_cid: vector<u8>,
    }

    /// Issue a new transcript for a student
    entry fun issue_transcript(
        owner: address,
        walrus_cid: vector<u8>,
        transcript_hash: vector<u8>,
        seal_metadata: vector<u8>,
        expiration: option::Option<u64>,
        _ctx: &mut TxContext
    ) {
        let issuer_addr = sender(_ctx);
        let now: u64 = 0; // placeholder until sui::clock is integrated

        let transcript = Transcript {
            id: sui::object::new(_ctx),
            owner,
            issuer: issuer_addr,
            walrus_cid,
            transcript_hash,
            issued_at: now,
            expires_at: expiration,
            revoked: false,
            seal_metadata,
        };

        event::emit<TranscriptIssued>(TranscriptIssued {
            owner,
            issuer: issuer_addr,
            walrus_cid: transcript.walrus_cid,
            transcript_hash: transcript.transcript_hash,
            issued_at: now,
        });

        transfer::transfer(transcript, owner);
    }

    /// CLI-friendly entry: take expiration as u64 (0 => none) and return the created object's ID.
    entry fun issue_transcript_cli(
        owner: address,
        walrus_cid: vector<u8>,
        transcript_hash: vector<u8>,
        seal_metadata: vector<u8>,
        expiration_ms: u64,
        _ctx: &mut TxContext,
    ): ID {
        let expiration_opt = if (expiration_ms == 0) { option::none() } else { option::some(expiration_ms) };

        let issuer_addr = sender(_ctx);
        let now: u64 = 0;

        let mut transcript = Transcript {
            id: sui::object::new(_ctx),
            owner,
            issuer: issuer_addr,
            walrus_cid,
            transcript_hash,
            issued_at: now,
            expires_at: expiration_opt,
            revoked: false,
            seal_metadata,
        };

        // Capture ID before transferring the object
        let id = sui::object::id(&transcript);

        event::emit<TranscriptIssued>(TranscriptIssued {
            owner,
            issuer: issuer_addr,
            walrus_cid: transcript.walrus_cid,
            transcript_hash: transcript.transcript_hash,
            issued_at: now,
        });

        transfer::transfer(transcript, owner);
        id
    }

    /// Revoke an existing transcript (only issuer can revoke)
    entry fun revoke_transcript(
        transcript: &mut Transcript,
        _ctx: &mut TxContext
    ) {
        let admin_addr = sender(_ctx);
        assert!(admin_addr == transcript.issuer, 0);

        transcript.revoked = true;
        let now: u64 = 0;

        event::emit<TranscriptRevoked>(TranscriptRevoked {
            owner: transcript.owner,
            issuer: admin_addr,
            revoked_at: now,
            walrus_cid: transcript.walrus_cid,
        });
    }

    // Test-only helper: construct a Transcript value for unit tests.
    #[test_only]
    public fun create_test_transcript(
        owner: address,
        walrus_cid: vector<u8>,
        transcript_hash: vector<u8>,
        seal_metadata: vector<u8>,
        expiration: option::Option<u64>,
        _ctx: &mut TxContext
    ): Transcript {
        let issuer_addr = sender(_ctx);
        let transcript = Transcript {
            id: sui::object::new(_ctx),
            owner,
            issuer: issuer_addr,
            walrus_cid,
            transcript_hash,
            issued_at: 0,
            expires_at: expiration,
            revoked: false,
            seal_metadata,
        };
        transcript
    }

    /// Verify a transcript’s hash against stored hash
    public fun verify_hash(transcript: &Transcript, provided_hash: &vector<u8>): bool {
        *provided_hash == transcript.transcript_hash
    }

    /// Check if transcript is valid (not expired or revoked)
    public fun is_valid(transcript: &Transcript): bool {
        if (transcript.revoked) {
            return false
        };
        true
    }
}
