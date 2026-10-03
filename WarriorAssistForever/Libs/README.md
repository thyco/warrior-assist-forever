# Bundled libraries

- LibCustomGlow-1.0, minor version 25: copied byte-for-byte from the user's DKForce addon. Upstream: https://github.com/Stanzilla/LibCustomGlow . The DKForce copy includes a TextureUtil.AnimateTexCoords compatibility adjustment; no changes were made here. Upstream MIT license and the DKForce distribution's MIT notice are included alongside the Lua file.
- LibStub, minor version 2: copied byte-for-byte from DKForce. Its public-domain declaration and contributor credits are retained in the source header.

These libraries load before addon modules. LibStub selects the newest registered compatible library when multiple addons bundle it. No separate addon installation is required.
