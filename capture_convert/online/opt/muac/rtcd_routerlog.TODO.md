# TODO: rtcd_routerlog.awk improvements

- [ ] Guard header parsing: if neither `RTCD_SNIFFED_ADDRESS >` nor `> RTCD_SNIFFED_ADDRESS` matches, skip the line to avoid invalid `ip_address`.
- [ ] Prevent buffer stall: treat packet complete when `processedLength >= dataLength`; add overshoot reset/guard.
- [ ] Make IP header length dynamic by parsing IHL from the first byte of the IP header; avoid assuming 20-byte header.
- [ ] Adjust `dataLength` calculation when VLAN/802.1Q is present or base completion on actual hex dump length.
- [ ] Make payload extraction robust: avoid fixed `45...81` regex; use computed header length or parse payload directly.
- [ ] Add defensive reset when a new header appears before previous payload completes (log/skip partial).
- [ ] Improve hex parsing resilience: use `IGNORECASE=1` or `[0-9A-Fa-f]` in regexes for hex digits.
