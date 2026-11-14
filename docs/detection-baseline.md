# Detector baseline

The 2026-11-14 baseline uses the Linux x86_64 release produced by GitHub Actions for commit `eee46955955726f64798a14f9ecc0e73a9592cc9`, version `1.1.0-dev.12167+eee469559`. Its SHA-256 is `e05d87ad7f816c82a57152ff7765f23987c3266bed00bf9395ed32f9e27d1377`. The CI binary also started on the project host after building with `-Dcpu=x86_64`.

The [CI run](https://github.com/pygojrc/browser/actions/runs/43583126319) retains the original detector output, stderr, and exit status in the `detector-baseline` artifact. These are headless fetches from a GitHub runner, not controlled comparisons of IP, time zone, or interaction.

| Detector | Observation |
| --- | --- |
| Sannysoft | UA `Lightpanda/1.0`; `window.chrome` missing; plugin count 0 and PluginArray type test failed; WebGL context unavailable. |
| botstop | Page remained at the probe-running stage after the configured wait; no verdict was obtained. |
| rebrowser | Detection table remained empty; its Chromium-specific automation setup was not performed. No verdict was obtained. |

All three fetch processes exited zero; that means the fetch command completed, not that the detector finished or passed. Detector results can change, and a score alone is not a browser compatibility guarantee.

WebGL is not currently available, and no WebGL compatibility switch is yet
implemented. Any future implementation needs a separate disable switch and a
regression case proving that disabling it restores the existing no-context
behavior for sites that cannot work with the implementation.

A separate same-host, headed ms_chromium 149 comparison on Sannysoft showed a Mozilla/Chrome UA, `window.chrome`, five PDF plugins and a WebGL context. Its launcher enabled a random fingerprint seed and the request was made from a different environment, so this is an illustrative reference rather than an isolated A/B measurement.
