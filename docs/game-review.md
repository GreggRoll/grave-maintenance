# Grave Maintenance — independent game review

Reviewed 5 October 2026 after the lobby, equipment, cemetery boundary, and phone-control changes.

## Evidence and limits

This review combines the current source, engine-driven GUI/input and layout checks, and captured browser screenshots (`ui-home.jpg`, `ui-trailer.jpg`, `ui-inventory.jpg`, `ui-shop.jpg`, and `phone-landscape.jpg`). My reviewer environment exposed no browser or computer surfaces, so I did not personally play a browser session or a physical iPhone. The implementation agent separately exercised the browser and reported passing milestone, boundary, controls, and four-client multiplayer suites. Physical Safari performance, keyboard appearance, rotation with active touches, and network latency still require device play.

Independent checks performed:

- Measured the visible button bounds in Trailer, My equipment, and Shop at 390×844, 844×390, and 1280×800. No horizontal button overflow was found.
- Entered a name through the real scene's LineEdit, then sent mouse motion/down/up to Host a game. The revised silent focus-exit save preserved the first click and the host form opened. Mouse motion is necessary in this headless GUI test; an earlier synthetic attempt without it did not establish hover and was not reliable evidence.
- Measured landscape extraction-confirmation and results button positions. Confirmation buttons fit. Results initially overflowed after increasing touch targets, and the revised scroll container makes Another shift reachable: y588–672 within the 720-high logical viewport after scrolling.
- Inspected standard-monster movement, target filtering, and the boundary regression. Standard threats remain inside the grounds and cannot kill a player on the road; witches retain their exception.

## What improved

The home screen now presents a useful sequence: editable identity, Host / Join / Solo choices, then the public-game list. Connection details are tucked away. The empty-state text tells a first-time player what to do next, and the warm primary action stands out against the dark cemetery palette.

Preparation gives wallet, equipment value at risk, and trailer capacity one consistent location. Trailer / My equipment / Shop separates three distinct decisions: what the crew is taking, what I own, and what I can buy. Packed versus at-home labels and explicit Pack / Unpack verbs are easier to understand than offers. Buying switches to ownership, where the purchase must be deliberately packed; this makes risk a visible choice.

Phone controls are visible and stable: a movement stick, contextual work action, and drop/exit/return action. Simultaneous movement and tool use, releasing one finger while another remains active, focus loss, and blocked/dead states are covered in the scene input checks. The cemetery boundary gives players a readable escape destination without making the witching deadline safe.

## Findings addressed during review

1. **First-click reliability after editing identity.** A synchronous focus-exit name save could rebuild the UI during navigation. The implementation now saves without a local full-screen notification. The revised GUI test confirms the first Host click opens the form and the new name persists.
2. **Shared trailer visibility.** The Trailer view originally listed only my tools while its capacity number represented the whole crew. The implementation now includes teammates' packed equipment with owner labels and read-only rows. This aligns the loadout view with its team purpose.
3. **Phone extraction wording.** At the truck, the contextual text offered extraction while the primary phone action said Take. It now says Extract when extraction is the actual action.
4. **Landscape anticipation.** The earlier 1.65 camera zoom and broad HUD bands restricted the unobstructed vertical view on 844×390. Landscape zoom has been widened to 1.4. Whether this provides enough reaction time against werewolf/vampire bursts should be judged on a real phone, especially over a public connection.
5. **Consistent touch action sizes.** Results and extraction confirmation initially used desktop-size buttons on landscape phones because the shared button helper checked logical width rather than touch mode. The helper now uses touch mode as well.

6. **Landscape replay reachability.** Increasing touch target size exposed a results-panel overflow: at 844×390, Another shift extended from y705 to789 beyond the 720-high logical viewport. Results now use a safe-area scroll container. An independent engine layout check scrolled the panel and confirmed the full button is inside the viewport at y588–672. Extraction confirmation remains fully contained.

## Remaining feedback

No verified release-blocking issue remains from this review. The captured shop makes basic / upgrade / pro tiers, ownership count, affordability, and balance after purchase easy to compare. One small copy improvement: when inventory is empty after a loss, consider “Shop / replace tools” instead of “Buy better equipment”; free basic replacements are useful recovery actions, and “buy better” understates that path. The landscape camera and reaction time against fast threats need hands-on tuning. The widened 1.4 zoom is an improvement; screenshot/source review cannot establish whether a player can reliably see and respond to a burst chase on an actual phone. Test this before spending time on additional art.

## Next playtest focus

Use a physical iPhone for one full five-minute shift in both orientations. Verify name entry does not obscure navigation, walking and holding a blower/washer work together, safe-range cleaning remains readable under a thumb, near-gate escape is understandable, the 2:55 warning is conspicuous, extraction warns clearly about loss, and another shift remains reachable. Test on the public server because authoritative movement without prediction can feel different over internet latency.

The next useful iteration is this focused device playtest and small camera/interaction tuning. Additional jobs, inventories, or combat would dilute the prototype's current work → mistake → escape → return decision.
