//! Mekanism: Tools for Horizon — slice 1, the 72 items (data tier).
//!
//! One flat SDK package (mod API 0.2): the 72 items, their models, textures,
//! equipment layers, language file, recipes and tags are the carried `assets/`
//! and `data/` here, and this crate is the package's code half. The rules
//! themselves live in [`runtime`], byte-identical to the retired `.hnmod`
//! bundle's `runtime.rs`: a **census**, not behaviour.
//!
//! The retired bundle had no `[[injection]]` either. A data-tier mod ships
//! registrations and data, not hooks: every item is declared in
//! `data/mekanismtools/horizon/item/*.json` as a copy of a 26.3 vanilla template,
//! and the game builds the item from that declaration. So the one `impl Hooks`
//! below is empty on purpose — it is what makes this a native SDK package, and
//! what carries the compiled census to `cargo test`.
//!
//! | Retired (0.1.0) | Here (0.2.0) |
//! |---|---|
//! | `[[module]] runtime` (a same-crate module, no injection) | `pub mod runtime` |
//! | `content/` (a second `.hmod` inside the bundle) | `assets/` + `data/` at this root |
//! | `[[injection]]`s | none — there were none to carry |
//!
//! A later slice that needs behaviour (per-material stats, or the client half
//! that draws the shields' plates) adds hook methods or Parts here, and its
//! rules go in [`runtime`] or a sibling module; nothing in the carried content
//! has to move for that.
pub mod runtime;

use mod_api::{self, Hooks};

/// The mod. The macro boxes one `Default` instance for the session; this port
/// keeps no state, so the struct is empty.
#[derive(Default)]
struct Mod;

#[mod_api::horizon_mod]
impl Hooks for Mod {}
