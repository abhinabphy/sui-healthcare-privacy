pragma circom 2.2.1;

include "../node_modules/circomlib/circuits/poseidon.circom";
include "../node_modules/circomlib/circuits/comparators.circom";
include "../node_modules/circomlib/circuits/mux1.circom";

template HealthcareDisclosure() {
    // Public inputs
    signal input disclosed_parameter;
    signal input disclosure_index;
    signal input commitment;

    // Private inputs
    signal input blood_pressure;
    signal input heart_rate;
    signal input temperature;
    signal input oxygen;
    signal input respiratory_rate;

    // Internal signals
    signal c[5];
    signal c2D[5][2];
    
    // Calculate commitment hash
    component hasher = Poseidon(5);
    hasher.inputs[0] <== blood_pressure;
    hasher.inputs[1] <== heart_rate;
    hasher.inputs[2] <== temperature;
    hasher.inputs[3] <== oxygen;
    hasher.inputs[4] <== respiratory_rate;

    // Verify commitment
    commitment === hasher.out;

    // Prepare parameter array
    c[0] <== blood_pressure;
    c[1] <== heart_rate;
    c[2] <== temperature;
    c[3] <== oxygen;
    c[4] <== respiratory_rate;

    // Convert to 2D array for multiplexer
    for (var i = 0; i < 5; i++) {
        c2D[i][0] <== c[i];
        c2D[i][1] <== 0;
    }

    // Parameter selection
    component mux = MultiMux1(5);
    mux.c <== c2D;
    mux.s <== disclosure_index;

    // Verify disclosed parameter
    disclosed_parameter === mux.out[0];

    // Verify index bounds
    component lessThan = LessThan(3);
    lessThan.in[0] <== disclosure_index;
    lessThan.in[1] <== 5;
    lessThan.out === 1;
}

component main = HealthcareDisclosure();