# Compact unit direction codec

This directory carries the backend-neutral executable fixture for the compact
three-dimensional direction representation extracted from the Android
accelerometer work.

A direction on `S²` is equivalently a unit pure quaternion
`0 + x i + y j + z k`. The codec stores the direction in exactly three bytes
as two signed Q0.11 coordinates in the standard octahedral chart, packed as
adjacent 12-bit two's-complement integers.

This is deliberately **not** a full orientation-quaternion (`S³`) codec and it
contains no accelerometer-specific magnitude, balanced-gravity reference, or
physical unit. Those belong to the sensor model that consumes this direction
codec.

The C header and host test are kept byte-for-byte aligned with the generic
codec extracted in `Ashtray-Archer/utilities-android-phone-user`. The matching
Idriç exact storage model lives in
`isomorphisms/Idric` under
`_/examples/unified-higher-mathematics/CompactUnitDirectionStorage.idric`.

Run the host fixture from an arbitrary working directory:

```sh
sh shared/compact-unit-direction/test.sh
```

The test fixes the six principal-axis byte encodings, rejection of zero and
nonfinite input, unit-length decoding, and the Q0.11 sphere error bound. It is a
portable codec receipt, not evidence for any particular embedded backend or
physical sensor.
