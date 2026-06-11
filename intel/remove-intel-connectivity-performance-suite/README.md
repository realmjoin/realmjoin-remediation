# Remove Intel Connectivity Performance Suite (ICPS)

Performs a clean removal of all Intel Connectivity Performance Suite components following Intel support article [000093451](https://www.intel.com/content/www/us/en/support/articles/000093451/wireless/wireless-software.html).

| Component | Detail |
|---|---|
| AppxPackage | `AppUp.IntelConnectivityPerformanceSuite_8j3eq9eme6ctt` – removed for all users and deprovisioned |
| PnP Drivers | All `oem#.inf` entries matching `icpsExtension` or `icpsComponent` - just detected, not removed as Windows Update installs them again |
| Service | `IntelNCS`, `IntelNCS2`, `Intel Network Connectivity Service`, `Intel Connectivity Network Service` |

## Background
The Intel Connectivity Performance Suite may cause network issues when IPv6 is enabled. This can be observed in Chromium-based browsers such as Microsoft Edge, Google Chrome and Brave, where connections fail with the error "ERR_CONNECTION_RESET".

## References

- [Intel: How to Uninstall or Roll Back to an Older Version of Intel® Connectivity Performance Suite Software](https://www.intel.com/content/www/us/en/support/articles/000093451/wireless/wireless-software.html)
- [Brave Community: ERR_CONNECTION_RESET errors on new Win 11 laptops](https://community.brave.app/t/err-connection-reset-errors-on-new-win-11-laptops/637663)
- [Intel Support Community: Intel Connectivity Network Service is causing the ipv6 flowtable attribute set to 0](https://community.intel.com/t5/Wireless/Intel-Connectivity-Network-Service-is-causing-the-ipv6-flowtable/m-p/1724934)