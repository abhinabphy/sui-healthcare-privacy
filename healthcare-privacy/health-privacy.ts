// health-privacy.ts
import { JsonRpcProvider, RawSigner, TransactionBlock } from '@mysten/sui.js';
import { groth16 } from 'snarkjs';
import { buildPoseidon } from 'circomlibjs';

export class HealthPrivacySystem {
    private provider: JsonRpcProvider;
    private signer: RawSigner;
    private packageId: string;
    private poseidon: any;

    constructor(
        provider: JsonRpcProvider,
        signer: RawSigner,
        packageId: string
    ) {
        this.provider = provider;
        this.signer = signer;
        this.packageId = packageId;
    }

    async initialize() {
        this.poseidon = await buildPoseidon();
    }

    async createProfile(healthData: {
        blood_pressure: number;
        heart_rate: number;
        temperature: number;
        oxygen: number;
        respiratory_rate: number;
    }) {
        const commitment = await this.generateCommitment(healthData);

        const tx = new TransactionBlock();
        tx.moveCall({
            target: `${this.packageId}::profile::create_profile`,
            arguments: [
                tx.pure(Array.from(commitment)),
                tx.pure(5)
            ]
        });

        return await this.signer.signAndExecuteTransactionBlock({
            transactionBlock: tx
        });
    }

    async grantAccess(
        profileId: string,
        viewer: string,
        parameterIndex: number,
        healthData: any,
        expiration?: number
    ) {
        const { proof, publicSignals } = await this.generateProof(
            healthData,
            parameterIndex
        );

        const tx = new TransactionBlock();
        tx.moveCall({
            target: `${this.packageId}::profile::grant_access`,
            arguments: [
                tx.object(profileId),
                tx.pure(viewer),
                tx.pure(parameterIndex),
                tx.pure(Array.from(proof)),
                tx.pure(expiration || null)
            ]
        });

        return await this.signer.signAndExecuteTransactionBlock({
            transactionBlock: tx
        });
    }

    private async generateCommitment(data: any): Promise<Uint8Array> {
        const values = [
            data.blood_pressure,
            data.heart_rate,
            data.temperature,
            data.oxygen,
            data.respiratory_rate
        ];
        return new Uint8Array(
            Buffer.from(
                this.poseidon.F.toString(this.poseidon(values))
            )
        );
    }

    private async generateProof(data: any, parameterIndex: number) {
        const commitment = await this.generateCommitment(data);
        
        const input = {
            disclosed_parameter: Object.values(data)[parameterIndex],
            disclosure_index: parameterIndex,
            commitment: commitment,
            ...data
        };

        return await groth16.fullProve(
            input,
            'healthcare_circuit.wasm',
            'healthcare_circuit.zkey'
        );
    }
}