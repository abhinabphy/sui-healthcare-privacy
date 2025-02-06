// sources/health_privacy.move
module health_privacy::profile{
    use sui::object::{Self, ID, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::event;
    use sui::table::{Self, Table};
    use std::vector;
    use std::option::{Self, Option};

    // Error constants
    const EInvalidProof: u64 = 0;
    const EUnauthorized: u64 = 1;
    const EInvalidParameter: u64 = 2;
    const EProfileNotFound: u64 = 3;
    const ECapabilityRevoked: u64 = 4;

    const MAX_PARAMETERS: u8 = 5;

    public struct HealthProfile has key {
        id: UID,
        owner: address,
        commitment: vector<u8>,
        parameters_count: u8,
        access_table: Table<address, AccessConfig>,
        is_active: bool,
        created_at: u64,
        updated_at: Option<u64>
    }

    public struct AccessConfig has store {
        allowed_parameters: vector<u8>,
        expiration: Option<u64>,
        revoked: bool
    }

    public struct ViewCapability has key {
        id: UID,
        profile_id: ID,
        viewer: address,
        parameter_index: u8,
        proof: vector<u8>,
        expiration: Option<u64>
    }

    // Events
    public struct ProfileCreated has copy, drop {
        profile_id: ID,
        owner: address,
        timestamp: u64
    }

    public struct AccessGranted has copy, drop {
        profile_id: ID,
        viewer: address,
        parameter_index: u8,
        timestamp: u64
    }

    public struct AccessRevoked has copy, drop {
        profile_id: ID,
        viewer: address,
        timestamp: u64
    }

    public entry fun create_profile(
        commitment: vector<u8>,
        parameters_count: u8,
        ctx: &mut TxContext
    ) {
        assert!(parameters_count <= MAX_PARAMETERS, EInvalidParameter);
        
        let sender = tx_context::sender(ctx);
        let timestamp = tx_context::epoch(ctx);
        
        let profile = HealthProfile {
            id: object::new(ctx),
            owner: sender,
            commitment,
            parameters_count,
            access_table: table::new(ctx),
            is_active: true,
            created_at: timestamp,
            updated_at: option::none()
        };

        event::emit(ProfileCreated {
            profile_id: object::uid_to_inner(&profile.id),
            owner: sender,
            timestamp
        });

        transfer::transfer(profile, sender)
    }

    public entry fun grant_access(
        profile: &mut HealthProfile,
        viewer: address,
        parameter_index: u8,
        proof: vector<u8>,
        expiration: Option<u64>,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == profile.owner, EUnauthorized);
        assert!(parameter_index < profile.parameters_count, EInvalidParameter);
        assert!(!vector::is_empty(&proof), EInvalidProof);

        let timestamp = tx_context::epoch(ctx);

        let access_config = if (table::contains(&profile.access_table, viewer)) {
            let mut config = table::remove(&mut profile.access_table, viewer);
            if (!vector::contains(&config.allowed_parameters, &parameter_index)) {
                vector::push_back(&mut config.allowed_parameters, parameter_index);
            };
            config.expiration = expiration;
            config.revoked = false;
            config
        } else {
            AccessConfig {
                allowed_parameters: vector[parameter_index],
                expiration,
                revoked: false
            }
        };
        table::add(&mut profile.access_table, viewer, access_config);

        let cap = ViewCapability {
            id: object::new(ctx),
            profile_id: object::uid_to_inner(&profile.id),
            viewer,
            parameter_index,
            proof,
            expiration
        };

        event::emit(AccessGranted {
            profile_id: object::uid_to_inner(&profile.id),
            viewer,
            parameter_index,
            timestamp
        });

        transfer::transfer(cap, viewer)
    }

    public fun view_parameter(
        profile: &HealthProfile,
        cap: &ViewCapability,
        parameter: vector<u8>,
        ctx: &TxContext
    ): vector<u8> {
        assert!(object::uid_to_inner(&profile.id) == cap.profile_id, EInvalidProof);
        
        let access_config = table::borrow(&profile.access_table, cap.viewer);
        assert!(!access_config.revoked, ECapabilityRevoked);
        assert!(vector::contains(&access_config.allowed_parameters, &cap.parameter_index), EUnauthorized);
        
        if (option::is_some(&cap.expiration)) {
            assert!(
                *option::borrow(&cap.expiration) > tx_context::epoch(ctx), 
                ECapabilityRevoked
            );
        };

        parameter
    }
}
